import assert from "node:assert/strict";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { DateTime } from "luxon";
assert.equal(process.env.GCLOUD_PROJECT, "demo-mediflow");
assert.ok(
  process.env.FIRESTORE_EMULATOR_HOST &&
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
  "Only use this tool with the Auth/Firestore demo emulators.",
);
initializeApp({ projectId: "demo-mediflow" });
const db = getFirestore();
const auth = getAuth();
try {
  await auth.deleteUser("browser-newstaff");
} catch (error) {
  if (error.code !== "auth/user-not-found") throw error;
}
await auth.createUser({
  uid: "browser-newstaff",
  email: "browser-newstaff@example.test",
  password: "Emulator-only-password1!",
});
const now = DateTime.now().setZone("Africa/Cairo");
for (const year of process.env.MEDIFLOW_SPARK_TARGET === "staff"
  ? []
  : [now.year, now.year + 1]) {
  let offset = DateTime.utc(year).setZone("Africa/Cairo").offset;
  const changes = [];
  for (
    let t = DateTime.utc(year).plus({ hours: 1 });
    t.year === year;
    t = t.plus({ hours: 1 })
  ) {
    const current = t.setZone("Africa/Cairo").offset;
    if (current !== offset) {
      changes.push(t.toMillis());
      offset = current;
    }
  }
  assert.equal(changes.length, 2);
  await db.doc(`clinicTimezones/${year}`).set({
    dstStart: Timestamp.fromMillis(changes[0]),
    dstEnd: Timestamp.fromMillis(changes[1]),
  });
}
const visits = await db.collection("appointments").get();
const counts = new Map();
for (const doc of visits.docs) {
  const visit = doc.data();
  const at = Math.floor(visit.dateTime.toMillis() / 1800000) * 1800000;
  const startKey = String(at);
  await doc.ref.update({
    dateTime: Timestamp.fromMillis(at),
    startKey,
    periodIndex: DateTime.fromMillis(at, { zone: "Africa/Cairo" }).weekday - 1,
    updatedBy: visit.patientId,
  });
  await db
    .doc(`patientHistory/${visit.patientId}`)
    .set({ firstAppointmentId: doc.id });
  await db
    .doc(`doctorPatients/${visit.doctorUserId}/patients/${visit.patientId}`)
    .set({ patientId: visit.patientId, appointmentId: doc.id });
  if (["pending", "confirmed", "in_progress"].includes(visit.status)) {
    const lock = { appointmentId: doc.id, dateTime: Timestamp.fromMillis(at) };
    await db
      .doc(`doctorReservations/${visit.doctorId}/slots/${startKey}`)
      .set(lock);
    await db
      .doc(`patientReservations/${visit.patientId}/slots/${startKey}`)
      .set(lock);
    counts.set(visit.doctorId, (counts.get(visit.doctorId) ?? 0) + 1);
  } else if (!counts.has(visit.doctorId)) counts.set(visit.doctorId, 0);
}
for (const [id, activeCount] of counts)
  await db
    .doc(`bookingGuards/${id}`)
    .set({ activeCount, lastAppointmentId: "emulator-seed" });
const users = await db.collection("users").get();
const doctors = await db.collection("doctors").get();
for (const doc of doctors.docs) {
  await db.doc(`users/${doc.data().userId}`).update({ doctorId: doc.id });
  const minutes = (value) =>
    Number(value.split(":")[0]) * 60 + Number(value.split(":")[1]);
  const days = [
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
  ];
  const week = Object.fromEntries(
    days.map((day) => [day, Array(48).fill("0")]),
  );
  for (const period of doc.data().availability) {
    if (!period.isActive) continue;
    const start = minutes(period.startTime),
      end = minutes(period.endTime);
    for (
      let index = Math.ceil(start / 30);
      index < 47 && (index + 1) * 30 <= end;
      index++
    )
      week[period.day][index] = "1";
  }
  await doc.ref.update({
    availability: Object.fromEntries(
      days.map((day) => [day, week[day].join("")]),
    ),
  });
}
for (const doc of users.docs)
  await db.doc(`accountEmails/${doc.data().email}`).set({ userId: doc.id });
console.log(
  "Spark emulator calendar, reservations and history fixtures prepared; no live data used.",
);
