import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { before, beforeEach, after, test } from "node:test";
import assert from "node:assert/strict";
const require = createRequire(import.meta.url);
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  getDoc,
  writeBatch,
  serverTimestamp,
  updateDoc,
  deleteDoc,
} = require("firebase/firestore");
let environment;
before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Use the demo-mediflow emulator only.",
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
beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());
const dbFor = (uid = "new-patient", email = "new@example.test") =>
  environment.authenticatedContext(uid, { email }).firestore();
function enrollment(db, overrides = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, "accountEmails/new@example.test"), {
    userId: "new-patient",
  });
  batch.set(doc(db, "users/new-patient"), {
    id: "new-patient",
    email: "new@example.test",
    fullName: "New Patient",
    phone: "+201000000000",
    role: "patient",
    isActive: true,
    avatarUrl: null,
    gender: null,
    dateOfBirth: null,
    address: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  });
  return batch.commit();
}
test("Spark patient enrollment succeeds atomically without a callable server", async () => {
  const db = dbFor();
  await assertSucceeds(enrollment(db));
  assert.equal(
    (await getDoc(doc(db, "users/new-patient"))).data().role,
    "patient",
  );
  assert.equal(
    (await getDoc(doc(db, "accountEmails/new@example.test"))).data().userId,
    "new-patient",
  );
});
for (const [name, overrides] of Object.entries({
  "admin escalation": { role: "admin" },
  "doctor escalation": { role: "doctor" },
  "foreign UID": { id: "other" },
  "foreign email": { email: "other@example.test" },
  "inactive enrollment": { isActive: false },
  "unknown privileged field": { admin: true },
  "forged timestamp": { createdAt: new Date(0) },
  "invalid name": { fullName: "x" },
  "invalid phone": { phone: "private" },
  "spaces without a name": { fullName: "   " },
  "phone punctuation without enough digits": { phone: "12 (  ) -" },
}))
  test(`Spark enrollment rejects ${name}`, async () =>
    assertFails(enrollment(dbFor(), overrides)));
test("enrollment requires email ownership, an email reservation, and server time", async () => {
  await assertFails(enrollment(dbFor("other", "new@example.test")));
  await assertFails(enrollment(dbFor("new-patient", "other@example.test")));
  const db = dbFor();
  await assertFails(setDoc(doc(db, "users/new-patient"), { role: "patient" }));
  await assertFails(
    setDoc(doc(db, "accountEmails/new@example.test"), {
      userId: "new-patient",
    }),
  );
});
test("email reservations and removed identities cannot be stolen or recreated", async () => {
  await environment.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), "accountEmails/new@example.test"), {
      userId: "previous",
    });
  });
  await assertFails(enrollment(dbFor()));
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), "revokedUsers/new-patient"), {
      revoked: true,
    });
  });
  await assertFails(enrollment(dbFor()));
});
test("enrolled patients cannot rewrite roles, timestamps, or email reservations", async () => {
  const db = dbFor();
  await enrollment(db);
  await assertFails(updateDoc(doc(db, "users/new-patient"), { role: "admin" }));
  await assertFails(
    updateDoc(doc(db, "users/new-patient"), { updatedAt: new Date(0) }),
  );
  await assertFails(
    updateDoc(doc(db, "accountEmails/new@example.test"), { userId: "other" }),
  );
  await assertFails(deleteDoc(doc(db, "accountEmails/new@example.test")));
  await assertFails(getDoc(doc(db, "accountEmails/other@example.test")));
  await assertFails(getDoc(doc(db, "revokedUsers/other")));
});
