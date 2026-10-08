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
