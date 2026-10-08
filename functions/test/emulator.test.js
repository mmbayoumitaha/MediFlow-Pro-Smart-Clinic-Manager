import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";
import {
  initializeApp as initializeAdminApp,
  deleteApp as deleteAdminApp,
} from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getAuth as getAdminAuth } from "firebase-admin/auth";
import { createRequire } from "node:module";
import { DateTime } from "luxon";
import { createClinicService } from "../src/service.js";
import { CLINIC_ZONE } from "../src/policy.js";
import { patientEditable, doctorEditable } from "../src/policy.js";
import { provisionAdmin } from "../src/provision_admin.js";
const require = createRequire(import.meta.url);
const { initializeApp, deleteApp } = require("firebase/app");
const {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
} = require("firebase/auth");
const {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} = require("firebase/functions");

const projectId = "demo-mediflow";
const password = "Emulator-only-password1!";
const roles = {
  p1: "patient",
  p2: "patient",
  "d-user1": "doctor",
  "d-user2": "doctor",
  admin: "admin",
  disabled: "patient",
};
let adminApp, db, adminAuth, date, start, fixtures;
const apps = [];
const clients = new Map();
async function client(uid) {
  if (clients.has(uid)) return clients.get(uid);
  const app = initializeApp(
    {
      projectId,
      apiKey: "fake-emulator-key",
      authDomain: `${projectId}.firebaseapp.com`,
    },
    uid,
  );
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(
    auth,
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`,
    { disableWarnings: true },
  );
  const functions = getFunctions(app, "us-central1");
  const [host, port] = process.env.FUNCTIONS_EMULATOR_HOST?.split(":") ?? [
    "127.0.0.1",
    "15001",
  ];
  connectFunctionsEmulator(functions, host, Number(port));
  if (uid !== "anonymous")
    await signInWithEmailAndPassword(auth, `${uid}@example.test`, password);
  const result = async (name, input) =>
    (await httpsCallable(functions, name)(input)).data;
  clients.set(uid, result);
  return result;
}
before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST &&
      process.env.FIREBASE_AUTH_EMULATOR_HOST,
    "Run with Firebase Auth/Firestore/Functions emulators; never live credentials.",
  );
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  adminApp = initializeAdminApp({ projectId });
  db = getFirestore(adminApp);
  adminAuth = getAdminAuth(adminApp);
  for (const uid of [...Object.keys(roles), "new-patient"]) {
    try {
      await adminAuth.deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    await adminAuth.createUser({ uid, email: `${uid}@example.test`, password });
  }
  const tomorrow = DateTime.now()
    .setZone(CLINIC_ZONE)
    .plus({ days: 1 })
    .startOf("day");
  date = tomorrow.toISODate();
  start = tomorrow.set({ hour: 9 }).toMillis();
  const day = tomorrow.toFormat("cccc").toLowerCase();
  const stamp = Timestamp.fromMillis(Date.now());
  fixtures = Object.fromEntries(
    Object.entries(roles).map(([id, role]) => [
      `users/${id}`,
      {
        id,
        role,
        isActive: id !== "disabled",
        email: `${id}@example.test`,
        fullName: `Test ${id}`,
        phone: "+201000000000",
        createdAt: stamp,
        updatedAt: stamp,
      },
    ]),
  );
  for (const suffix of [1, 2])
    fixtures[`doctors/d${suffix}`] = {
      id: `d${suffix}`,
      userId: `d-user${suffix}`,
      fullName: `Test Doctor ${suffix}`,
      email: `d-user${suffix}@example.test`,
      phone: "+201000000000",
      specialty: "general_practice",
      consultationFee: 80.25,
      experienceYears: 0,
      bio: null,
      rating: 0,
      totalReviews: 0,
      isAvailable: true,
      availability: [
        { day, startTime: "09:00", endTime: "11:00", isActive: true },
      ],
      createdAt: stamp,
    };
});
beforeEach(async () => {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.ok(response.ok);
  const batch = db.batch();
  for (const [path, value] of Object.entries(fixtures))
    batch.set(db.doc(path), value);
  await batch.commit();
});
after(async () => {
  await Promise.all(apps.map(deleteApp));
  if (db) await db.terminate();
  if (adminApp) await deleteAdminApp(adminApp);
});
const booking = (id = "request-one", overrides = {}) => ({
  requestId: id,
  doctorId: "d1",
  startMillis: start,
  expectedFee: 80.25,
  expectedSpecialty: "general_practice",
  reason: "Consultation",
  ...overrides,
});
const fails = (operation, code) =>
  assert.rejects(operation, (error) => error.code === `functions/${code}`);

test("callables authenticate the token and deny missing/inactive/nonpatient accounts", async () => {
  for (const [uid, code] of [
    ["anonymous", "unauthenticated"],
    ["disabled", "permission-denied"],
    ["d-user1", "permission-denied"],
    ["admin", "permission-denied"],
  ]) {
    const call = await client(uid);
    await fails(call("bookAppointment", booking()), code);
    await fails(call("availableSlots", { doctorId: "d1", date }), code);
  }
  assert.equal((await db.collection("appointments").get()).size, 0);
});
test("registration derives email/UID from Auth and provisions only a patient, with safe retry", async () => {
  const call = await client("new-patient");
  const input = { fullName: "  New Patient  ", phone: "+201000000000" };
  await fails(
    call("completePatientRegistration", { ...input, role: "admin" }),
    "invalid-argument",
  );
  await fails(
    call("completePatientRegistration", { ...input, id: "admin" }),
    "invalid-argument",
  );
  const patient = await call("completePatientRegistration", input);
  assert.equal(patient.id, "new-patient");
  assert.equal(patient.email, "new-patient@example.test");
  assert.equal(patient.role, "patient");
  assert.equal(patient.fullName, "New Patient");
  assert.deepEqual(await call("completePatientRegistration", input), patient);
  await fails(
    call("completePatientRegistration", {
      ...input,
      fullName: "Different Name",
    }),
    "already-exists",
  );
  const doctorCall = await client("d-user1");
  await fails(
    doctorCall("completePatientRegistration", input),
    "already-exists",
  );
  assert.equal((await db.doc("users/d-user1").get()).data().role, "doctor");
});
test("booking rejects forged owner/actor/status/price and writes canonical trusted fields", async () => {
  const call = await client("p1");
  for (const extra of [
    { patientId: "p2" },
    { actor: { role: "admin" } },
    { status: "completed" },
    { doctorName: "forged" },
  ]) {
    await fails(
      call("bookAppointment", { ...booking(), ...extra }),
      "invalid-argument",
    );
  }
  await fails(
    call("bookAppointment", booking("request-one", { expectedFee: 1 })),
    "failed-precondition",
  );
  await fails(
    call(
      "bookAppointment",
      booking("request-one", { expectedSpecialty: "cardiology" }),
    ),
    "failed-precondition",
  );
  const visit = await call("bookAppointment", booking());
  assert.equal(visit.patientId, "p1");
  assert.equal(visit.patientName, "Test p1");
  assert.equal(visit.doctorUserId, "d-user1");
  assert.equal(visit.fee, 80.25);
  assert.equal(visit.status, "pending");
  assert.equal(visit.paymentStatus, "unpaid");
  assert.equal(visit.durationMinutes, 30);
  assert.equal(Date.parse(visit.dateTime), start);
  assert.equal(
    (await db.doc("doctorPatients/d-user1/patients/p1").get()).data().id,
    "p1",
  );
});
test("competing patients cannot double-book a doctor; losing response exposes no patient data", async () => {
  const [p1, p2] = await Promise.all([client("p1"), client("p2")]);
  const result = await Promise.allSettled([
    p1("bookAppointment", booking("first")),
    p2("bookAppointment", booking("second")),
  ]);
  assert.equal(result.filter((item) => item.status === "fulfilled").length, 1);
  const failure = result.find((item) => item.status === "rejected").reason;
  assert.equal(failure.code, "functions/failed-precondition");
  assert.equal(failure.details, undefined);
  assert.equal((await db.collection("appointments").get()).size, 1);
  const available = await p2("availableSlots", { doctorId: "d1", date });
  assert.deepEqual(Object.keys(available).sort(), ["startMillis", "zone"]);
  assert.equal(available.zone, CLINIC_ZONE);
  assert.ok(!available.startMillis.includes(start));
});
test("the same patient cannot reserve overlapping visits across doctors", async () => {
  const call = await client("p1");
  const result = await Promise.allSettled([
    call("bookAppointment", booking("first")),
    call("bookAppointment", booking("second", { doctorId: "d2" })),
  ]);
  assert.equal(result.filter((item) => item.status === "fulfilled").length, 1);
  assert.equal((await db.collection("appointments").get()).size, 1);
});
test("identical retries are acknowledged, changed/foreign requests cannot reuse an ID", async () => {
  const p1 = await client("p1"),
    p2 = await client("p2");
  const result = await Promise.all([
    p1("bookAppointment", booking()),
    p1("bookAppointment", booking()),
  ]);
  assert.deepEqual(result[0], result[1]);
  assert.equal((await db.collection("appointments").get()).size, 1);
  await fails(
    p1("bookAppointment", booking("request-one", { reason: "Changed" })),
    "already-exists",
  );
  await fails(p2("bookAppointment", booking()), "already-exists");
  // A delayed acknowledgement remains retryable after availability/fee changes.
  await db
    .doc("doctors/d1")
    .update({ isAvailable: false, consultationFee: 99 });
  assert.deepEqual(await p1("bookAppointment", booking()), result[0]);
});
test("availability rejects malformed dates, stale profile, outside hours and off-grid instants", async () => {
  const call = await client("p1");
  await fails(
    call("availableSlots", { doctorId: "d1", date: "2026-02-30" }),
    "invalid-argument",
  );
  await fails(
    call("bookAppointment", booking("one", { startMillis: Date.now() })),
    "invalid-argument",
  );
  for (const startMillis of [start + 15 * 60000, start + 2 * 60 * 60000]) {
    await fails(
      call("bookAppointment", booking("one", { startMillis })),
      "failed-precondition",
    );
  }
  await db.doc("users/d-user1").update({ isActive: false });
  await fails(call("bookAppointment", booking()), "failed-precondition");
  assert.equal((await db.collection("appointments").get()).size, 0);
});
test("status changes enforce trusted ownership, expected status and preserve payment", async () => {
  const p1 = await client("p1"),
    p2 = await client("p2"),
    d1 = await client("d-user1"),
    d2 = await client("d-user2");
  await p1("bookAppointment", booking());
  const command = {
    appointmentId: "request-one",
    expectedStatus: "pending",
    targetStatus: "confirmed",
  };
  await fails(p1("changeAppointmentStatus", command), "failed-precondition");
  await fails(p2("changeAppointmentStatus", command), "permission-denied");
  await fails(d2("changeAppointmentStatus", command), "permission-denied");
  const confirmed = await d1("changeAppointmentStatus", command);
  assert.equal(confirmed.status, "confirmed");
  assert.equal(confirmed.paymentStatus, "unpaid");
  await fails(d1("changeAppointmentStatus", command), "aborted");
  await fails(
    d1("changeAppointmentStatus", {
      ...command,
      expectedStatus: "confirmed",
      targetStatus: "in_progress",
    }),
    "failed-precondition",
  );
  const cancelled = await p1("changeAppointmentStatus", {
    ...command,
    expectedStatus: "confirmed",
    targetStatus: "cancelled",
  });
  assert.equal(cancelled.status, "cancelled");
  assert.ok(
    (await p2("availableSlots", { doctorId: "d1", date })).startMillis.includes(
      start,
    ),
  );
});
test("server clock controls check-in/completion/no-show independently of the caller", async () => {
  const p1 = await client("p1");
  await p1("bookAppointment", booking());
  let time = start;
  const service = createClinicService(db, adminAuth, { now: () => time });
  await service.changeAppointmentStatus("d-user1", {
    appointmentId: "request-one",
    expectedStatus: "pending",
    targetStatus: "confirmed",
  });
  await service.changeAppointmentStatus("d-user1", {
    appointmentId: "request-one",
    expectedStatus: "confirmed",
    targetStatus: "in_progress",
  });
  await service.changeAppointmentStatus("d-user1", {
    appointmentId: "request-one",
    expectedStatus: "in_progress",
    targetStatus: "completed",
  });
  assert.equal(
    (await db.doc("appointments/request-one").get()).data().status,
    "completed",
  );
  const second = { ...booking("second"), startMillis: start + 30 * 60000 };
  await p1("bookAppointment", second);
  time = start + 60 * 60000;
  const noShow = await service.changeAppointmentStatus("admin", {
    appointmentId: "second",
    expectedStatus: "pending",
    targetStatus: "no_show",
  });
  assert.equal(noShow.status, "no_show");
});

const editable = (value, keys) =>
  Object.fromEntries(keys.map((key) => [key, value[key] ?? null]));
const patientExpected = async (id) =>
  editable(
    { ...(await db.doc(`users/${id}`).get()).data(), id },
    patientEditable,
  );
const doctorExpected = async (id) =>
  editable(
    { ...(await db.doc(`doctors/${id}`).get()).data(), id },
    doctorEditable,
  );
const contactInput = (overrides = {}) => ({
  fullName: "Updated Patient",
  phone: "+201111111111",
  address: "Clinic test address",
  isActive: true,
  ...overrides,
});
const doctorInput = (overrides = {}) => ({
  fullName: "New Doctor",
  email: "new-doctor@example.test",
  phone: "+201000000000",
  specialty: "general_practice",
  consultationFee: 50.25,
  experienceYears: 5,
  bio: null,
  availability: fixtures["doctors/d1"].availability,
  isAvailable: true,
  ...overrides,
});
async function completedVisit(id = "completed") {
  const stamp = Timestamp.fromMillis(Date.now() - 3600000);
  await db.doc(`appointments/${id}`).set({
    id,
    patientId: "p1",
    patientName: "Test p1",
    doctorId: "d1",
    doctorUserId: "d-user1",
    doctorName: "Test Doctor 1",
    specialty: "general_practice",
    fee: 80.25,
    durationMinutes: 30,
    status: "completed",
    paymentStatus: "unpaid",
    dateTime: stamp,
    createdAt: stamp,
    updatedAt: stamp,
  });
}
test("only active admins issue invoices; issuance uses historical fees and is idempotent under contention", async () => {
  await completedVisit();
  const command = { appointmentId: "completed", invoiceId: "invoice-one" };
  for (const uid of ["p1", "d-user1", "disabled"])
    await fails(
      (await client(uid))("issueAppointmentInvoice", command),
      "permission-denied",
    );
  const call = await client("admin");
  await db.doc("doctors/d1").update({ consultationFee: 999 });
  const invoices = await Promise.all([
    call("issueAppointmentInvoice", command),
    call("issueAppointmentInvoice", { ...command, invoiceId: "invoice-two" }),
  ]);
  assert.deepEqual(invoices[0], invoices[1]);
  assert.equal(invoices[0].total, 80.25);
  assert.equal(invoices[0].items[0].quantity, 1);
  assert.equal((await db.collection("invoices").get()).size, 1);
  assert.equal(
    (await db.doc("appointments/completed").get()).data().paymentStatus,
    "unpaid",
  );
});
test("settlement/refund atomically update invoice and linked payment state without changing lifecycle", async () => {
  await completedVisit();
  const call = await client("admin");
  await call("issueAppointmentInvoice", {
    appointmentId: "completed",
    invoiceId: "invoice",
  });
  const command = {
    invoiceId: "invoice",
    expectedPayment: "unpaid",
    targetPayment: "paid",
    method: "bankTransfer",
  };
  for (const uid of ["p1", "d-user1", "disabled"])
    await fails(
      (await client(uid))("recordInvoicePayment", command),
      "permission-denied",
    );
  await fails(
    call("recordInvoicePayment", { ...command, method: "unsupported" }),
    "failed-precondition",
  );
  const payments = await Promise.allSettled([
    call("recordInvoicePayment", command),
    call("recordInvoicePayment", command),
  ]);
  assert.equal(
    payments.filter((result) => result.status === "fulfilled").length,
    1,
  );
  assert.equal(
    payments.find((result) => result.status === "rejected").reason.code,
    "functions/aborted",
  );
  const paid = (await db.doc("invoices/invoice").get()).data();
  assert.equal(paid.paymentStatus, "paid");
  assert.equal(paid.paymentMethod, "bankTransfer");
  assert.equal(
    (await db.doc("appointments/completed").get()).data().paymentStatus,
    "paid",
  );
  assert.equal(
    (await db.doc("appointments/completed").get()).data().status,
    "completed",
  );
  const refunded = await call("recordInvoicePayment", {
    invoiceId: "invoice",
    expectedPayment: "paid",
    targetPayment: "refunded",
  });
  assert.equal(refunded.paymentMethod, "bankTransfer");
  assert.equal(Date.parse(refunded.paidDate), paid.paidDate.toMillis());
  assert.equal(
    (await db.doc("appointments/completed").get()).data().paymentStatus,
    "refunded",
  );
  await fails(
    call("recordInvoicePayment", { ...command, expectedPayment: "refunded" }),
    "failed-precondition",
  );
});
test("malformed invoices, wrong links, duplicate links and zero-fee visits cannot be settled", async () => {
  await completedVisit();
  const call = await client("admin");
  await call("issueAppointmentInvoice", {
    appointmentId: "completed",
    invoiceId: "invoice",
  });
  const ref = db.doc("invoices/invoice"),
    original = (await ref.get()).data();
  const command = {
    invoiceId: "invoice",
    expectedPayment: "unpaid",
    targetPayment: "paid",
    method: "cash",
  };
  for (const mutation of [
    { total: 1 },
    { items: [] },
    { patientId: "p2" },
    { issuedDate: Timestamp.fromMillis(Date.now() + 86400000) },
  ]) {
    await ref.set({ ...original, ...mutation });
    await assert.rejects(call("recordInvoicePayment", command));
    assert.equal(
      (await db.doc("appointments/completed").get()).data().paymentStatus,
      "unpaid",
    );
  }
  await ref.set(original);
  await db.doc("invoices/duplicate").set({ ...original, id: "duplicate" });
  await fails(call("recordInvoicePayment", command), "aborted");
  await completedVisit("free");
  await db.doc("appointments/free").update({ fee: 0 });
  await fails(
    call("issueAppointmentInvoice", {
      appointmentId: "free",
      invoiceId: "free-invoice",
    }),
    "failed-precondition",
  );
});
test("patient edits are owner-scoped, stale forms fail, projections update and identity/history are preserved", async () => {
  const p1 = await client("p1");
  await p1("bookAppointment", booking());
  const expected = await patientExpected("p1"),
    command = { expected, contact: contactInput() };
  await fails(
    (await client("p2"))("savePatient", command),
    "permission-denied",
  );
  await fails(
    (await client("d-user1"))("savePatient", command),
    "permission-denied",
  );
  await fails(
    p1("savePatient", {
      ...command,
      contact: contactInput({ isActive: false }),
    }),
    "permission-denied",
  );
  await fails(
    p1("savePatient", {
      ...command,
      contact: { ...contactInput(), role: "admin" },
    }),
    "invalid-argument",
  );
  const result = await p1("savePatient", command);
  assert.equal(result.email, "p1@example.test");
  assert.equal(result.role, "patient");
  assert.equal(
    (await db.doc("doctorPatients/d-user1/patients/p1").get()).data().fullName,
    "Updated Patient",
  );
  assert.equal(
    (await db.doc("appointments/request-one").get()).data().patientName,
    "Test p1",
  );
  await fails(p1("savePatient", command), "aborted");
  const admin = await client("admin");
  await admin("savePatient", {
    expected: await patientExpected("p1"),
    contact: contactInput({ isActive: false }),
  });
  await fails(
    p1(
      "bookAppointment",
      booking("second", { startMillis: start + 30 * 60000 }),
    ),
    "permission-denied",
  );
  await fails(
    p1("availableSlots", { doctorId: "d1", date }),
    "permission-denied",
  );
  assert.equal(
    (await db.doc("doctorPatients/d-user1/patients/p1").get()).data().isActive,
    false,
  );
});
test("doctor edits require ownership and fresh forms; working changes retain reservations and original visit fees", async () => {
  await (
    await client("p1")
  )("bookAppointment", booking());
  const expected = await doctorExpected("d1"),
    profile = doctorInput({ email: expected.email, consultationFee: 90 });
  const command = { expected, profile };
  await fails(
    (await client("d-user2"))("saveDoctor", command),
    "permission-denied",
  );
  await fails((await client("p1"))("saveDoctor", command), "permission-denied");
  const call = await client("d-user1");
  await fails(
    call("saveDoctor", {
      expected,
      profile: { ...profile, email: "changed@example.test" },
    }),
    "invalid-argument",
  );
  const shifted = profile.availability.map((period) => ({
    ...period,
    startTime: "09:30",
  }));
  await fails(
    call("saveDoctor", {
      expected,
      profile: { ...profile, availability: shifted },
    }),
    "aborted",
  );
  await call("saveDoctor", {
    expected,
    profile: { ...profile, isAvailable: false },
  });
  assert.equal(
    (await db.doc("users/d-user1").get()).data().fullName,
    "New Doctor",
  );
  assert.equal(
    (await db.doc("appointments/request-one").get()).data().fee,
    80.25,
  );
  assert.equal(
    (await db.doc("appointments/request-one").get()).data().doctorName,
    "Test Doctor 1",
  );
  await fails(call("saveDoctor", command), "aborted");
});
test("doctor provisioning is admin-only, recoverable, rejects existing Auth identities and prevents patient self-enrollment", async () => {
  const input = {
    expected: null,
    profile: doctorInput(),
    newDoctorId: "new-doc",
    newUserId: "new-doc-user",
  };
  for (const uid of ["p1", "d-user1", "disabled"])
    await fails((await client(uid))("saveDoctor", input), "permission-denied");
  const call = await client("admin");
  const results = await Promise.all([
    call("saveDoctor", input),
    call("saveDoctor", {
      ...input,
      newDoctorId: "retry-doc",
      newUserId: "retry-user",
    }),
  ]);
  assert.deepEqual(results[0], results[1]);
  const doctor = results[0];
  assert.equal(
    (await db.doc(`users/${doctor.userId}`).get()).data().role,
    "doctor",
  );
  assert.equal((await db.collection("doctors").get()).size, 3);
  assert.equal(
    (await adminAuth.getUser(doctor.userId)).email,
    input.profile.email,
  );
  // Existing staff/Auth email identities are never taken over through provisioning.
  const other = {
    ...input,
    newDoctorId: "other-doc",
    newUserId: "p2",
    profile: doctorInput({ email: "another@example.test" }),
  };
  await fails(call("saveDoctor", other), "already-exists");
  assert.equal((await adminAuth.getUser("p2")).email, "p2@example.test");
  // Durable request recovers after Auth exists but before the profile transaction.
  const service = createClinicService(db, {
    ...adminAuth,
    createUser: async (data) => {
      const created = await adminAuth.createUser(data);
      throw Object.assign(new Error("Ambiguous acknowledgement"), {
        code: "transient",
      });
    },
    getUser: (id) => adminAuth.getUser(id),
  });
  const recovery = {
    ...input,
    newDoctorId: "recovery-doc",
    newUserId: "recovery-user",
    profile: doctorInput({ email: "recovery@example.test" }),
  };
  await assert.rejects(service.saveDoctor("admin", recovery));
  assert.ok(!(await db.doc("users/recovery-user").get()).exists);
  const healed = await call("saveDoctor", recovery);
  assert.equal(healed.userId, "recovery-user");
  assert.equal(
    (await db.doc("staffProvisioning/recovery-user").get()).data().completed,
    true,
  );
  const duplicateEmailResponse = createClinicService(db, {
    createUser: async (data) => {
      await adminAuth.createUser(data);
      throw Object.assign(new Error("Duplicate after creation"), {
        code: "auth/email-already-exists",
      });
    },
    getUser: (id) => adminAuth.getUser(id),
  });
  const duplicateRecovery = await duplicateEmailResponse.saveDoctor("admin", {
    ...input,
    newDoctorId: "email-recovery-doc",
    newUserId: "email-recovery-user",
    profile: doctorInput({ email: "email-recovery@example.test" }),
  });
  assert.equal(duplicateRecovery.userId, "email-recovery-user");
});
test("preexisting unenrolled Auth accounts are not promoted, even when UID and email are supplied by an admin", async () => {
  const call = await client("admin");
  const input = {
    expected: null,
    newDoctorId: "untrusted-doctor",
    newUserId: "new-patient",
    profile: doctorInput({ email: "new-patient@example.test" }),
  };
  await fails(call("saveDoctor", input), "already-exists");
  assert.ok(!(await db.doc("users/new-patient").get()).exists);
  assert.equal((await adminAuth.getUser("new-patient")).displayName, undefined);
  const pendingClient = await client("new-patient");
  await fails(
    pendingClient("completePatientRegistration", {
      fullName: "New Patient",
      phone: "+201000000000",
    }),
    "permission-denied",
  );
});
test("deletion rejects all historical references and stale/foreign requests; removed identities cannot self-recreate", async () => {
  const call = await client("admin"),
    p1 = await client("p1");
  await p1("bookAppointment", booking());
  const expected = await patientExpected("p1");
  await fails(p1("removePatient", { expected }), "permission-denied");
  await fails(call("removePatient", { expected }), "failed-precondition");
  await fails(
    call("removeDoctor", { expected: await doctorExpected("d1") }),
    "failed-precondition",
  );
  const p2 = await patientExpected("p2");
  await fails(
    call("removePatient", { expected: { ...p2, fullName: "stale" } }),
    "aborted",
  );
  await call("removePatient", { expected: p2 });
  assert.ok(!(await db.doc("users/p2").get()).exists);
  await fails(
    (await client("p2"))("completePatientRegistration", {
      fullName: "Test p2",
      phone: "+201000000000",
    }),
    "permission-denied",
  );
  await call("removeDoctor", { expected: await doctorExpected("d2") });
  assert.ok(!(await db.doc("users/d-user2").get()).exists);
  assert.ok(!(await db.doc("doctors/d2").get()).exists);
  await fails(
    (await client("d-user2"))("availableSlots", { doctorId: "d1", date }),
    "permission-denied",
  );
});
test("profile changes/deletion and booking serialize, so neither loses reservations or leaks an inactive account", async () => {
  const p1 = await client("p1"),
    admin = await client("admin"),
    expected = await doctorExpected("d1");
  const profile = doctorInput({
    email: expected.email,
    availability: expected.availability.map((period) => ({
      ...period,
      startTime: "09:30",
    })),
  });
  const race = await Promise.allSettled([
    p1("bookAppointment", booking()),
    admin("saveDoctor", { expected, profile }),
  ]);
  assert.equal(
    race.filter((result) => result.status === "fulfilled").length,
    1,
  );
  const records = await db.collection("appointments").get();
  if (!records.empty)
    assert.equal(
      (await db.doc("doctors/d1").get()).data().availability[0].startTime,
      "09:00",
    );
  else
    assert.equal(
      (await db.doc("doctors/d1").get()).data().availability[0].startTime,
      "09:30",
    );
});
test("initial admin provisioning stays outside callables and refuses promotion of patient/doctor/removed identities", async () => {
  await db.doc("users/admin").delete();
  const input = { fullName: "Clinic Owner", phone: "+201000000000" };
  const result = await provisionAdmin(db, adminAuth, "admin", input);
  assert.equal(result.role, "admin");
  assert.equal(result.email, "admin@example.test");
  for (const id of ["p1", "d-user1"])
    await assert.rejects(
      provisionAdmin(db, adminAuth, id, input),
      (error) => error.code === "failed-precondition",
    );
  await db.doc("users/new-patient").delete();
  await db.doc("revokedUsers/new-patient").set({ revokedAt: Timestamp.now() });
  await assert.rejects(
    provisionAdmin(db, adminAuth, "new-patient", input),
    (error) => error.code === "failed-precondition",
  );
});
