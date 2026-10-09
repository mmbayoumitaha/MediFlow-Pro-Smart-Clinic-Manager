import assert from "node:assert/strict";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { DateTime } from "luxon";

const projectId = "demo-mediflow";
assert.equal(process.env.GCLOUD_PROJECT, projectId);
assert.ok(
  process.env.FIREBASE_AUTH_EMULATOR_HOST &&
    process.env.FIRESTORE_EMULATOR_HOST,
  "This fixture tool requires both local emulators; it must never write to a real project.",
);
const app = initializeApp({ projectId });
const auth = getAuth(app),
  db = getFirestore(app);
try {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.ok(response.ok);
  const stamp = Timestamp.now(),
    now = DateTime.now().setZone("Africa/Cairo");
  const batch = db.batch();
  const roles = {
    "browser-patient": "patient",
    "browser-other": "patient",
    "browser-doctor": "doctor",
    "browser-doctor2": "doctor",
    "browser-admin": "admin",
  };
  const users = {};
  for (const [uid, role] of Object.entries(roles)) {
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    await auth.createUser({
      uid,
      email: `${uid}@example.test`,
      password: "Emulator-only-password1!",
    });
    const user = {
      id: uid,
      email: `${uid}@example.test`,
      fullName: `Fictional ${uid}`,
      phone: "+201000000000",
      address: null,
      role,
      isActive: true,
      createdAt: stamp,
      updatedAt: stamp,
    };
    users[uid] = user;
    batch.set(db.doc(`users/${uid}`), user);
  }
  for (const [id, userId] of [
    ["browser-doc1", "browser-doctor"],
    ["browser-doc2", "browser-doctor2"],
  ]) {
    batch.set(db.doc(`doctors/${id}`), {
      id,
      userId,
      fullName: `Fictional ${userId}`,
      email: `${userId}@example.test`,
      phone: "+201000000000",
      specialty: "general_practice",
      consultationFee: 80.25,
      experienceYears: 0,
      bio: null,
      rating: 0,
      totalReviews: 0,
      isAvailable: true,
      availability: [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
      ].map((day) => ({
        day,
        startTime: "09:00",
        endTime: "17:00",
        isActive: true,
      })),
      createdAt: stamp,
    });
  }
  for (const [id, patientId, doctorId, doctorUserId, time, status] of [
    [
      "browser-past",
      "browser-patient",
      "browser-doc1",
      "browser-doctor",
      now.minus({ hours: 1 }),
      "confirmed",
    ],
    [
      "browser-completed",
      "browser-patient",
      "browser-doc1",
      "browser-doctor",
      now.minus({ days: 1 }),
      "completed",
    ],
    [
      "browser-foreign",
      "browser-other",
      "browser-doc2",
      "browser-doctor2",
      now.plus({ days: 1 }).startOf("day").set({ hour: 9 }),
      "confirmed",
    ],
  ]) {
    batch.set(db.doc(`appointments/${id}`), {
      id,
      patientId,
      patientName: users[patientId].fullName,
      doctorId,
      doctorUserId,
      doctorName: users[doctorUserId].fullName,
      specialty: "general_practice",
      dateTime: Timestamp.fromMillis(time.toMillis()),
      durationMinutes: 30,
      status,
      reason: null,
      notes: null,
      fee: 80.25,
      paymentStatus: "unpaid",
      createdAt: stamp,
      updatedAt: stamp,
    });
    batch.set(
      db.doc(`doctorPatients/${doctorUserId}/patients/${patientId}`),
      users[patientId],
    );
  }
  await batch.commit();
  console.log(
    "Seeded fictional browser workflows in demo-mediflow emulators only.",
  );
} finally {
  await db.terminate();
  await deleteApp(app);
}
