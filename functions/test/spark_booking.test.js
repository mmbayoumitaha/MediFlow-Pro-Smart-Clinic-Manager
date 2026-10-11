import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
import { DateTime } from "luxon";
const require = createRequire(import.meta.url);
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  runTransaction,
  serverTimestamp,
  Timestamp,
  collection,
  getDocs,
} = require("firebase/firestore");
let environment;
const days = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
];
const nextSlot = () =>
  DateTime.now()
    .setZone("Africa/Cairo")
    .plus({ days: 1 })
    .startOf("day")
    .set({ hour: 9 })
    .toMillis();
const dbFor = (uid) =>
  environment
    .authenticatedContext(uid, { email: `${uid}@example.test` })
    .firestore();
async function seed(extra = {}) {
  await environment.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    const values = {};
    for (const uid of ["p1", "p2", "d-u1", "d-u2", "admin"])
      values[`users/${uid}`] = {
        id: uid,
        email: `${uid}@example.test`,
        fullName: uid.startsWith("d-")
          ? `Doctor d${uid.slice(-1)}`
          : `Name ${uid}`,
        phone: "+201000000000",
        role:
          uid === "admin"
            ? "admin"
            : uid.startsWith("d-")
              ? "doctor"
              : "patient",
        isActive: true,
        createdAt: Timestamp.fromMillis(1),
        updatedAt: Timestamp.fromMillis(1),
        address: null,
        ...(uid.startsWith("d-") ? { doctorId: `d${uid.slice(-1)}` } : {}),
      };
    for (const id of ["d1", "d2"])
      values[`doctors/${id}`] = {
        id,
        userId: `d-u${id.slice(1)}`,
        fullName: `Doctor ${id}`,
        email: `d-u${id.slice(1)}@example.test`,
        phone: "+201000000000",
        specialty: "general_practice",
        consultationFee: 80.25,
        isAvailable: true,
        createdAt: Timestamp.fromMillis(1),
        bio: null,
        avatarUrl: null,
        experienceYears: 3,
        rating: 0,
        totalReviews: 0,
        availability: Object.fromEntries(
          days.map((day) => [
            day,
            "0".repeat(18) + "1".repeat(16) + "0".repeat(14),
          ]),
        ),
      };
    const year = DateTime.now().year;
    for (const y of [year, year + 1]) {
      let previous = DateTime.utc(y).setZone("Africa/Cairo").offset;
      const transitions = [];
      for (
        let t = DateTime.utc(y).plus({ hours: 1 });
        t.year === y;
        t = t.plus({ hours: 1 })
      ) {
        const offset = t.setZone("Africa/Cairo").offset;
        if (offset !== previous) {
          transitions.push(t.toMillis());
          previous = offset;
        }
      }
      assert.equal(transitions.length, 2);
      values[`clinicTimezones/${y}`] = {
        dstStart: Timestamp.fromMillis(transitions[0]),
        dstEnd: Timestamp.fromMillis(transitions[1]),
      };
    }
    Object.assign(values, extra);
    await Promise.all(
      Object.entries(values).map(([path, data]) => setDoc(doc(db, path), data)),
    );
  });
}
before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Use demo-mediflow emulators only.",
  );
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  environment = await initializeTestEnvironment({
    projectId: "demo-mediflow",
    firestore: {
      host,
      port: Number(port),
      rules: await readFile(
        new URL("../../firestore.rules", import.meta.url),
        "utf8",
      ),
    },
  });
});
beforeEach(async () => {
  await environment.clearFirestore();
  await seed();
});
after(async () => environment?.cleanup());
async function book(
  db,
  {
    uid = "p1",
    id = "a1",
    doctorId = "d1",
    at = nextSlot(),
    changes = {},
    omit = null,
  } = {},
) {
  return runTransaction(db, async (tx) => {
    const ref = doc(db, `appointments/${id}`);
    const old = await tx.get(ref);
    if (old.exists()) throw new Error("duplicate request");
    const user = (await tx.get(doc(db, `users/${uid}`))).data();
    const doctor = (await tx.get(doc(db, `doctors/${doctorId}`))).data();
    const key = String(at);
    const dlock = doc(db, `doctorReservations/${doctorId}/slots/${key}`);
    const plock = doc(db, `patientReservations/${uid}/slots/${key}`);
    const occupiedDoctor = await tx.get(dlock),
      occupiedPatient = await tx.get(plock);
    const guardRef = doc(db, `bookingGuards/${doctorId}`),
      historyRef = doc(db, `patientHistory/${uid}`);
    const careRef = doc(db, `doctorPatients/${doctor.userId}/patients/${uid}`);
    const guard = await tx.get(guardRef),
      history = await tx.get(historyRef),
      care = await tx.get(careRef);
    if (occupiedDoctor.exists() || occupiedPatient.exists())
      throw new Error("conflict");
    tx.set(ref, {
      id,
      patientId: uid,
      patientName: user.fullName,
      doctorId,
      doctorUserId: doctor.userId,
      doctorName: doctor.fullName,
      specialty: doctor.specialty,
      fee: doctor.consultationFee,
      dateTime: Timestamp.fromMillis(at),
      durationMinutes: 30,
      status: "pending",
      paymentStatus: "unpaid",
      notes: null,
      reason: "Routine visit",
      startKey: key,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      updatedBy: uid,
      ...changes,
    });
    const lock = { appointmentId: id, dateTime: Timestamp.fromMillis(at) };
    if (omit !== "doctor") tx.set(dlock, lock);
    if (omit !== "patient") tx.set(plock, lock);
    if (omit !== "guard")
      tx.set(guardRef, {
        activeCount: (guard.data()?.activeCount ?? 0) + 1,
        lastAppointmentId: id,
      });
    if (!history.exists() && omit !== "history")
      tx.set(historyRef, { firstAppointmentId: id });
    if (!care.exists() && omit !== "care")
      tx.set(careRef, { patientId: uid, appointmentId: id });
  });
}
test("rules-protected booking atomically reserves doctor and patient time with canonical details", async () => {
  const db = dbFor("p1");
  await assertSucceeds(book(db));
  const visit = (await getDoc(doc(db, "appointments/a1"))).data();
  assert.equal(visit.fee, 80.25);
  assert.equal(visit.status, "pending");
  assert.equal(
    (await getDoc(doc(db, "bookingGuards/d1"))).data().activeCount,
    1,
  );
  const publicRows = (
    await getDocs(collection(db, "doctorReservations/d1/slots"))
  ).docs;
  assert.deepEqual(Object.keys(publicRows[0].data()).sort(), [
    "appointmentId",
    "dateTime",
  ]);
  await assertFails(getDoc(doc(dbFor("p2"), "appointments/a1")));
  await assertFails(
    getDocs(collection(dbFor("p2"), "patientReservations/p1/slots")),
  );
  await assertSucceeds(getDoc(doc(dbFor("d-u1"), "users/p1")));
  await assertFails(getDoc(doc(dbFor("d-u2"), "users/p1")));
});
for (const omit of ["doctor", "patient", "guard", "history", "care"])
  test(`booking without atomic ${omit} record is denied`, async () =>
    assertFails(book(dbFor("p1"), { omit })));
for (const [name, changes] of Object.entries({
  fee: { fee: 0 },
  specialty: { specialty: "cardiology" },
  name: { patientName: "Other person" },
  "doctor owner": { doctorUserId: "d-u2" },
  "prepaid status": { paymentStatus: "paid" },
  "privileged field": { admin: true },
  "different duration": { durationMinutes: 60 },
  "stale actor": { updatedBy: "p2" },
}))
  test(`booking rejects forged ${name}`, async () =>
    assertFails(book(dbFor("p1"), { changes })));
test("concurrent patients cannot reserve the same doctor; the same patient cannot reserve two doctors", async () => {
  const results = await Promise.allSettled([
    book(dbFor("p1")),
    book(dbFor("p2"), { uid: "p2", id: "a2" }),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  await environment.clearFirestore();
  await seed();
  const other = await Promise.allSettled([
    book(dbFor("p1")),
    book(dbFor("p1"), { doctorId: "d2", id: "a2" }),
  ]);
  assert.equal(other.filter((r) => r.status === "fulfilled").length, 1);
});
test("unavailable doctors, inactive patients, today, distant dates and off-grid times are rejected", async () => {
  await assertFails(book(dbFor("p1"), { at: nextSlot() + 15 * 60000 }));
  await assertFails(
    book(dbFor("p1"), {
      at: DateTime.now()
        .setZone("Africa/Cairo")
        .startOf("day")
        .set({ hour: 9 })
        .toMillis(),
    }),
  );
  await assertFails(
    book(dbFor("p1"), {
      at: DateTime.fromMillis(nextSlot()).plus({ days: 15 }).toMillis(),
    }),
  );
  await seed({
    "doctors/d1": { id: "d1", userId: "d-u1", isAvailable: false },
  });
  await assert.rejects(book(dbFor("p1")));
});
test("confirmation preserves reservations; patient cancellation must release both locks and guard atomically", async () => {
  const patient = dbFor("p1"),
    staff = dbFor("d-u1");
  await book(patient);
  await assertFails(
    updateDoc(doc(patient, "appointments/a1"), {
      status: "confirmed",
      updatedAt: serverTimestamp(),
      updatedBy: "p1",
    }),
  );
  await assertSucceeds(
    updateDoc(doc(staff, "appointments/a1"), {
      status: "confirmed",
      updatedAt: serverTimestamp(),
      updatedBy: "d-u1",
    }),
  );
  await assertFails(
    deleteDoc(doc(patient, `doctorReservations/d1/slots/${nextSlot()}`)),
  );
  await assertFails(
    updateDoc(doc(patient, "appointments/a1"), {
      status: "cancelled",
      updatedAt: serverTimestamp(),
      updatedBy: "p1",
    }),
  );
  const batch = writeBatch(patient);
  batch.update(doc(patient, "appointments/a1"), {
    status: "cancelled",
    updatedAt: serverTimestamp(),
    updatedBy: "p1",
  });
  batch.delete(doc(patient, `doctorReservations/d1/slots/${nextSlot()}`));
  batch.delete(doc(patient, `patientReservations/p1/slots/${nextSlot()}`));
  batch.update(doc(patient, "bookingGuards/d1"), {
    activeCount: 0,
    lastAppointmentId: "a1",
  });
  await assertSucceeds(batch.commit());
  await assertFails(
    updateDoc(doc(patient, "appointments/a1"), {
      status: "pending",
      updatedAt: serverTimestamp(),
      updatedBy: "p1",
    }),
  );
  await assertSucceeds(book(dbFor("p2"), { uid: "p2", id: "a2" }));
});

async function completedVisit() {
  const at = nextSlot() - 2 * 86400000;
  await seed({
    "appointments/completed": {
      id: "completed",
      patientId: "p1",
      patientName: "Name p1",
      doctorId: "d1",
      doctorUserId: "d-u1",
      doctorName: "Doctor d1",
      specialty: "general_practice",
      fee: 80.25,
      dateTime: Timestamp.fromMillis(at),
      durationMinutes: 30,
      status: "completed",
      paymentStatus: "unpaid",
      notes: null,
      reason: "Consultation",
      startKey: String(at),
      periodIndex: 0,
      createdAt: Timestamp.fromMillis(at - 1000),
      updatedAt: Timestamp.fromMillis(at),
      updatedBy: "d-u1",
    },
  });
}
function invoiceData(id = "i1", changes = {}) {
  return {
    id,
    patientId: "p1",
    patientName: "Name p1",
    appointmentId: "completed",
    items: [
      {
        description: "Consultation with Doctor d1",
        quantity: 1,
        unitPrice: 80.25,
        total: 80.25,
      },
    ],
    subtotal: 80.25,
    total: 80.25,
    tax: 0,
    discount: 0,
    paymentStatus: "unpaid",
    paymentMethod: null,
    paidDate: null,
    issuedDate: serverTimestamp(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    updatedBy: "admin",
    ...changes,
  };
}
function issue(db, id = "i1", changes = {}, includeLink = true) {
  const batch = writeBatch(db);
  batch.set(doc(db, `invoices/${id}`), invoiceData(id, changes));
  if (includeLink)
    batch.set(doc(db, "billingLinks/completed"), { invoiceId: id });
  return batch.commit();
}
function settlement(
  db,
  {
    id = "i1",
    target = "paid",
    changes = {},
    includeVisit = true,
    actor = "admin",
  } = {},
) {
  const batch = writeBatch(db);
  batch.update(doc(db, `invoices/${id}`), {
    paymentStatus: target,
    updatedAt: serverTimestamp(),
    updatedBy: actor,
    ...(target === "paid"
      ? { paymentMethod: "cash", paidDate: serverTimestamp() }
      : {}),
    ...changes,
  });
  if (includeVisit)
    batch.update(doc(db, "appointments/completed"), {
      paymentStatus: target,
      updatedAt: serverTimestamp(),
      updatedBy: actor,
    });
  return batch.commit();
}
test("admin invoice issuance, settlement and refund atomically preserve the appointment lifecycle", async () => {
  await completedVisit();
  const db = dbFor("admin");
  await assertSucceeds(issue(db));
  await assertSucceeds(settlement(db));
  const paid = (await getDoc(doc(db, "invoices/i1"))).data();
  await assertSucceeds(settlement(db, { target: "refunded" }));
  const refund = (await getDoc(doc(db, "invoices/i1"))).data(),
    visit = (await getDoc(doc(db, "appointments/completed"))).data();
  assert.equal(refund.paidDate.toMillis(), paid.paidDate.toMillis());
  assert.equal(visit.status, "completed");
  assert.equal(visit.paymentStatus, "refunded");
  await assertFails(deleteDoc(doc(db, "invoices/i1")));
});
for (const [name, changes] of Object.entries({
  "patient identity": { patientId: "p2" },
  totals: { total: 1 },
  tax: { tax: 10 },
  discount: { discount: 5 },
  "line item": {
    items: [
      { description: "Tampered", quantity: 2, unitPrice: 40, total: 80.25 },
    ],
  },
  "paid creation": { paymentStatus: "paid" },
  "stale actor": { updatedBy: "p1" },
}))
  test(`invoice creation rejects forged ${name}`, async () => {
    await completedVisit();
    await assertFails(issue(dbFor("admin"), "i1", changes));
  });
test("invoice creation requires its unique link and rejects duplicates and uncompleted visits", async () => {
  await completedVisit();
  const db = dbFor("admin");
  await assertFails(issue(db, "i1", {}, false));
  await assertSucceeds(issue(db));
  await assertFails(issue(db, "i2"));
  await environment.clearFirestore();
  await seed();
  await completedVisit();
  await seed({
    "appointments/completed": {
      id: "completed",
      status: "pending",
      paymentStatus: "unpaid",
    },
  });
  await assertFails(issue(db));
});
test("invoice and visit payment records cannot be changed separately, by patients/doctors, or with tampered amounts", async () => {
  await completedVisit();
  const db = dbFor("admin");
  await issue(db);
  await assertFails(settlement(db, { includeVisit: false }));
  await assertFails(
    updateDoc(doc(db, "appointments/completed"), {
      paymentStatus: "paid",
      updatedAt: serverTimestamp(),
      updatedBy: "admin",
    }),
  );
  await assertFails(settlement(db, { changes: { total: 1 } }));
  await assertFails(
    settlement(db, { changes: { paidDate: Timestamp.fromMillis(1) } }),
  );
  await assertFails(settlement(dbFor("p1"), { actor: "p1" }));
  await assertFails(settlement(dbFor("d-u1"), { actor: "d-u1" }));
  const results = await Promise.allSettled([
    settlement(db),
    settlement(db, { changes: { paymentMethod: "card" } }),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  await assertFails(
    settlement(db, {
      target: "refunded",
      changes: { paidDate: serverTimestamp() },
    }),
  );
  await assertSucceeds(settlement(db, { target: "refunded" }));
  await assertFails(settlement(db));
});
test("patient contact updates preserve identity/history and are immediately readable by an associated doctor", async () => {
  const db = dbFor("p1");
  await book(db);
  await assertSucceeds(
    updateDoc(doc(db, "users/p1"), {
      fullName: "Updated Patient",
      phone: "+201111111111",
      address: "New address",
      updatedAt: serverTimestamp(),
      updatedBy: "p1",
    }),
  );
  assert.equal(
    (await getDoc(doc(dbFor("d-u1"), "users/p1"))).data().phone,
    "+201111111111",
  );
  assert.equal(
    (await getDoc(doc(db, "appointments/a1"))).data().patientName,
    "Name p1",
  );
  for (const changes of [
    { role: "doctor" },
    { email: "other@example.test" },
    { isActive: false },
    { updatedBy: "p2" },
  ]) {
    await assertFails(
      updateDoc(doc(db, "users/p1"), {
        ...changes,
        updatedAt: serverTimestamp(),
        updatedBy: changes.updatedBy ?? "p1",
      }),
    );
  }
  await assertFails(
    updateDoc(doc(dbFor("p2"), "users/p1"), {
      fullName: "Foreign edit",
      updatedAt: serverTimestamp(),
      updatedBy: "p2",
    }),
  );
});
function staffBatch(
  db,
  {
    uid = "new-staff",
    id = "new-doctor",
    changes = {},
    userChanges = {},
    includeEmail = true,
    includeUser = true,
  } = {},
) {
  const email = `${uid}@example.test`,
    batch = writeBatch(db);
  const base = {
    id,
    userId: uid,
    fullName: "New Doctor",
    email,
    phone: "+201000000000",
    avatarUrl: null,
    bio: null,
    specialty: "radiology",
    consultationFee: 99.25,
    experienceYears: 3,
    rating: 0,
    totalReviews: 0,
    availability: Object.fromEntries(
      days.map((day) => [
        day,
        "0".repeat(18) + "1".repeat(16) + "0".repeat(14),
      ]),
    ),
    isAvailable: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    updatedBy: "admin",
    ...changes,
  };
  batch.set(doc(db, `doctors/${id}`), base);
  if (includeUser)
    batch.set(doc(db, `users/${uid}`), {
      id: uid,
      email,
      fullName: "New Doctor",
      phone: "+201000000000",
      role: "doctor",
      isActive: true,
      avatarUrl: null,
      gender: null,
      dateOfBirth: null,
      address: null,
      doctorId: id,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      updatedBy: "admin",
      ...userChanges,
    });
  if (includeEmail)
    batch.set(doc(db, `accountEmails/${email}`), { userId: uid });
  return batch.commit();
}
test("only the administrator can atomically bind a new doctor UID, email and canonical profile", async () => {
  await assertFails(staffBatch(dbFor("p1")));
  await assertFails(staffBatch(dbFor("d-u1")));
  await assertFails(staffBatch(dbFor("admin"), { includeEmail: false }));
  await assertFails(staffBatch(dbFor("admin"), { includeUser: false }));
  await assertSucceeds(staffBatch(dbFor("admin")));
  await assertSucceeds(getDoc(doc(dbFor("new-staff"), "doctors/new-doctor")));
  await assertFails(
    getDoc(
      doc(
        environment
          .authenticatedContext("new-staff", { email: "foreign@example.test" })
          .firestore(),
        "doctors/new-doctor",
      ),
    ),
  );
  await assertFails(staffBatch(dbFor("admin"), { uid: "p1" }));
});
for (const [name, changes] of Object.entries({
  rating: { rating: 5 },
  "invalid fee precision": { consultationFee: 1.001 },
  "negative fee": { consultationFee: -1 },
  "invalid specialty": { specialty: "unknown" },
  "invalid hours": {
    availability: [
      { day: "monday", startTime: "22:00", endTime: "09:00", isActive: true },
    ],
  },
  "overnight grid": {
    availability: Object.fromEntries(days.map((day) => [day, "1".repeat(48)])),
  },
  "missing weekday": { availability: { monday: "0".repeat(48) } },
  "invalid schedule bit": {
    availability: Object.fromEntries(days.map((day) => [day, "2".repeat(48)])),
  },
  "foreign actor": { updatedBy: "p1" },
}))
  test(`doctor binding rejects ${name}`, async () =>
    assertFails(staffBatch(dbFor("admin"), { changes })));
function updateDoctor(db, changes = {}) {
  const batch = writeBatch(db);
  batch.update(doc(db, "doctors/d1"), {
    ...changes,
    updatedAt: serverTimestamp(),
    updatedBy: "d-u1",
  });
  batch.update(doc(db, "users/d-u1"), {
    fullName: changes.fullName ?? "Doctor d1",
    phone: changes.phone ?? "+201000000000",
    updatedAt: serverTimestamp(),
    updatedBy: "d-u1",
  });
  return batch.commit();
}
test("doctor contact edits update the trusted user atomically; ratings, identity and reserved schedules cannot change", async () => {
  const db = dbFor("d-u1");
  await assertSucceeds(
    updateDoctor(db, { fullName: "Updated Doctor", phone: "+201111111111" }),
  );
  assert.equal(
    (await getDoc(doc(db, "users/d-u1"))).data().fullName,
    "Updated Doctor",
  );
  await assertFails(updateDoctor(db, { rating: 5 }));
  await assertFails(updateDoctor(db, { email: "other@example.test" }));
  await assertFails(
    updateDoc(doc(db, "doctors/d1"), {
      fullName: "Unlinked name",
      updatedAt: serverTimestamp(),
      updatedBy: "d-u1",
    }),
  );
  await environment.clearFirestore();
  await seed();
  await book(dbFor("p1"));
  await assertFails(
    updateDoctor(db, {
      availability: Object.fromEntries(
        days.map((day) => [
          day,
          day === "monday"
            ? "0".repeat(20) + "1".repeat(4) + "0".repeat(24)
            : "0".repeat(48),
        ]),
      ),
    }),
  );
  await assertSucceeds(updateDoctor(db, { isAvailable: false }));
  const owner = dbFor("p1"),
    release = writeBatch(owner);
  release.update(doc(owner, "appointments/a1"), {
    status: "cancelled",
    updatedAt: serverTimestamp(),
    updatedBy: "p1",
  });
  release.delete(doc(owner, `doctorReservations/d1/slots/${nextSlot()}`));
  release.delete(doc(owner, `patientReservations/p1/slots/${nextSlot()}`));
  release.update(doc(owner, "bookingGuards/d1"), {
    activeCount: 0,
    lastAppointmentId: "a1",
  });
  await assertSucceeds(release.commit());
  await assertSucceeds(
    updateDoctor(db, {
      availability: Object.fromEntries(
        days.map((day) => [
          day,
          "0".repeat(20) + "1".repeat(4) + "0".repeat(24),
        ]),
      ),
    }),
  );
});
function removeUnused(db, id, role, doctorId = null) {
  const batch = writeBatch(db);
  batch.delete(doc(db, `users/${id}`));
  if (doctorId) batch.delete(doc(db, `doctors/${doctorId}`));
  batch.set(doc(db, `revokedUsers/${id}`), {
    userId: id,
    role,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}
test("unused deletion requires an immutable tombstone; any booking history blocks patient and doctor deletion", async () => {
  const db = dbFor("admin");
  await assertFails(deleteDoc(doc(db, "users/p2")));
  await assertSucceeds(removeUnused(db, "p2", "patient"));
  await assertFails(staffBatch(db, { uid: "p2" }));
  await assertFails(deleteDoc(doc(db, "revokedUsers/p2")));
  await assertSucceeds(removeUnused(db, "d-u2", "doctor", "d2"));
  await book(dbFor("p1"));
  await assertFails(removeUnused(db, "p1", "patient"));
  await assertFails(removeUnused(db, "d-u1", "doctor", "d1"));
});
