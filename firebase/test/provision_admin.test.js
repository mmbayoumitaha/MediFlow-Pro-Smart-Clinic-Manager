import assert from "node:assert/strict";
import { before, beforeEach, after, test } from "node:test";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { provisionAdmin } from "../src/provision_admin.js";
let app, db, auth;
const input = { fullName: "Clinic Owner" };
before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, "demo-mediflow");
  assert.ok(
    process.env.FIREBASE_AUTH_EMULATOR_HOST &&
      process.env.FIRESTORE_EMULATOR_HOST,
  );
  app = initializeApp({ projectId: "demo-mediflow" }, "operator-tests");
  db = getFirestore(app);
  auth = getAuth(app);
  for (const uid of [
    "owner",
    "patient",
    "doctor",
    "revoked",
    "disabled",
    "no-password",
  ]) {
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    await auth.createUser({
      uid,
      email: `${uid}@example.test`,
      disabled: uid === "disabled",
      ...(uid === "no-password"
        ? {}
        : { password: "Emulator-only-password1!" }),
    });
  }
});
beforeEach(async () => {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-mediflow/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.ok(response.ok);
});
after(async () => {
  if (db) await db.terminate();
  if (app) await deleteApp(app);
});
test("operator binds only the chosen Auth identity, reserves email and uses server timestamps", async () => {
  await provisionAdmin(db, auth, "owner", input);
  const profile = (await db.doc("users/owner").get()).data();
  assert.equal(profile.id, "owner");
  assert.equal(profile.email, "owner@example.test");
  assert.equal(profile.role, "admin");
  assert.equal(profile.isActive, true);
  assert.equal(profile.phone, "");
  assert.ok(profile.createdAt instanceof Timestamp);
  assert.equal(profile.createdAt.toMillis(), profile.updatedAt.toMillis());
  assert.deepEqual(
    (await db.doc("accountEmails/owner@example.test").get()).data(),
    { userId: "owner" },
  );
});
test("repeat owner provisioning preserves creation time and never needs a legacy clinic-wide lock", async () => {
  await provisionAdmin(db, auth, "owner", input);
  const stamp = (await db.doc("users/owner").get()).data().createdAt;
  await provisionAdmin(db, auth, "owner", {
    fullName: "Updated Owner",
    phone: "+201000000000",
  });
  const profile = (await db.doc("users/owner").get()).data();
  assert.equal(profile.fullName, "Updated Owner");
  assert.equal(profile.createdAt.toMillis(), stamp.toMillis());
  assert.equal((await db.doc("clinicLocks/current").get()).exists, false);
});
for (const role of ["patient", "doctor"])
  test(`operator cannot promote an existing ${role}`, async () => {
    await db.doc(`users/${role}`).set({ role, email: `${role}@example.test` });
    await assert.rejects(
      provisionAdmin(db, auth, role, input),
      (error) => error.code === "failed-precondition",
    );
    assert.equal((await db.doc(`users/${role}`).get()).data().role, role);
  });
test("removed identities and conflicting email reservations cannot become administrators", async () => {
  await db.doc("revokedUsers/revoked").set({ userId: "revoked" });
  await assert.rejects(
    provisionAdmin(db, auth, "revoked", input),
    (error) => error.code === "failed-precondition",
  );
  await db
    .doc("accountEmails/owner@example.test")
    .set({ userId: "someone-else" });
  await assert.rejects(
    provisionAdmin(db, auth, "owner", input),
    (error) => error.code === "failed-precondition",
  );
  assert.equal((await db.doc("users/owner").get()).exists, false);
});
test("disabled and non-password Auth identities fail closed", async () => {
  for (const uid of ["disabled", "no-password"])
    await assert.rejects(
      provisionAdmin(db, auth, uid, input),
      (error) => error.code === "failed-precondition",
    );
});
test("invalid owner inputs do not create trusted records", async () => {
  for (const details of [
    { fullName: "x" },
    { fullName: "Clinic Owner", phone: "123" },
    { fullName: "Clinic Owner", phone: "+x201000000000" },
  ])
    await assert.rejects(
      provisionAdmin(db, auth, "owner", details),
      (error) => error.code === "invalid-argument",
    );
  assert.equal((await db.doc("users/owner").get()).exists, false);
});
