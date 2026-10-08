import { readFile } from "node:fs/promises";
import { after, before, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
// RulesTestContext uses the compat SDK internally. Keep its SDK registrations
// in one CommonJS module graph instead of mixing compat ESM/CJS registries.
const require = createRequire(import.meta.url);
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  setDoc,
  updateDoc,
  deleteDoc,
} = require("firebase/firestore");

const projectId = "demo-mediflow";
let environment;
const paths = [
  "users/p1",
  "doctors/d1",
  "appointments/a1",
  "prescriptions/r1",
  "invoices/i1",
  "doctorPatients/d-user1/patients/p1",
  "clinicLocks/current",
  "unexpected/document",
];
before(async () => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Run using firebase emulators:exec; live projects are never used.",
  );
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  environment = await initializeTestEnvironment({
    projectId,
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
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all(
      Object.entries({
        "users/p1": {
          id: "p1",
          role: "patient",
          isActive: true,
          phone: "private-p1",
        },
        "users/p2": {
          id: "p2",
          role: "patient",
          isActive: true,
          phone: "private-p2",
        },
        "users/disabled": { id: "disabled", role: "patient", isActive: false },
        "users/d-user1": { id: "d-user1", role: "doctor", isActive: true },
        "users/d-user2": { id: "d-user2", role: "doctor", isActive: true },
        "users/admin": { id: "admin", role: "admin", isActive: true },
        "doctors/d1": { userId: "d-user1" },
        "doctors/d2": { userId: "d-user2" },
        "appointments/a1": { patientId: "p1", doctorUserId: "d-user1" },
        "appointments/a2": { patientId: "p2", doctorUserId: "d-user2" },
        "prescriptions/r1": { patientId: "p1", doctorUserId: "d-user1" },
        "prescriptions/r2": { patientId: "p2", doctorUserId: "d-user2" },
        "invoices/i1": { patientId: "p1" },
        "invoices/i2": { patientId: "p2" },
        "doctorPatients/d-user1/patients/p1": { id: "p1", role: "patient" },
        "doctorPatients/d-user2/patients/p2": { id: "p2", role: "patient" },
        "clinicLocks/current": { revision: 1 },
        "unexpected/document": { private: true },
      }).map(([path, value]) => setDoc(doc(db, path), value)),
    );
  });
});
after(async () => environment?.cleanup());
const dbFor = (uid) =>
  uid
    ? environment.authenticatedContext(uid).firestore()
    : environment.unauthenticatedContext().firestore();

for (const uid of [null, "missing", "disabled"]) {
  test(`${uid ?? "anonymous"} cannot read clinic data`, async () => {
    const db = dbFor(uid);
    for (const path of paths.filter((path) => !path.startsWith("users/")))
      await assertFails(getDoc(doc(db, path)));
    await assertFails(getDocs(collection(db, "users")));
  });
}
test("inactive and unprovisioned identities can observe only their own profile", async () => {
  await assertSucceeds(getDoc(doc(dbFor("disabled"), "users/disabled")));
  await assertSucceeds(getDoc(doc(dbFor("missing"), "users/missing")));
  await assertFails(getDoc(doc(dbFor("disabled"), "users/p1")));
});
test("patient reads own visits, prescriptions and invoices, plus the doctor directory", async () => {
  const db = dbFor("p1");
  for (const path of [
    "users/p1",
    "appointments/a1",
    "prescriptions/r1",
    "invoices/i1",
  ])
    await assertSucceeds(getDoc(doc(db, path)));
  assert.equal(
    (await assertSucceeds(getDocs(collection(db, "doctors")))).size,
    2,
  );
  for (const path of [
    "users/p2",
    "users/admin",
    "appointments/a2",
    "prescriptions/r2",
    "invoices/i2",
    "doctorPatients/d-user1/patients/p1",
  ])
    await assertFails(getDoc(doc(db, path)));
  for (const name of ["appointments", "prescriptions", "invoices"]) {
    const scoped = await assertSucceeds(
      getDocs(query(collection(db, name), where("patientId", "==", "p1"))),
    );
    assert.equal(scoped.size, 1);
    await assertFails(getDocs(collection(db, name)));
    await assertFails(
      getDocs(query(collection(db, name), where("patientId", "==", "p2"))),
    );
  }
  await assertFails(
    getDocs(query(collection(db, "users"), where("id", "==", "p1"))),
  );
});
test("doctor reads own profile, visits and private patient projections", async () => {
  const db = dbFor("d-user1");
  for (const path of [
    "users/d-user1",
    "doctors/d1",
    "appointments/a1",
    "prescriptions/r1",
    "doctorPatients/d-user1/patients/p1",
  ])
    await assertSucceeds(getDoc(doc(db, path)));
  assert.equal(
    (
      await assertSucceeds(
        getDocs(collection(db, "doctorPatients/d-user1/patients")),
      )
    ).size,
    1,
  );
  assert.equal(
    (
      await assertSucceeds(
        getDocs(
          query(collection(db, "doctors"), where("userId", "==", "d-user1")),
        ),
      )
    ).size,
    1,
  );
  for (const name of ["appointments", "prescriptions"]) {
    assert.equal(
      (
        await assertSucceeds(
          getDocs(
            query(collection(db, name), where("doctorUserId", "==", "d-user1")),
          ),
        )
      ).size,
      1,
    );
    await assertFails(getDocs(collection(db, name)));
    await assertFails(
      getDocs(
        query(collection(db, name), where("doctorUserId", "==", "d-user2")),
      ),
    );
  }
  for (const path of [
    "users/p1",
    "users/p2",
    "doctors/d2",
    "appointments/a2",
    "prescriptions/r2",
    "invoices/i1",
    "doctorPatients/d-user2/patients/p2",
  ])
    await assertFails(getDoc(doc(db, path)));
  await assertFails(getDocs(collection(db, "doctors")));
  await assertFails(getDocs(collection(db, "invoices")));
});
test("admin reads clinic records but cannot read internal or unknown collections", async () => {
  const db = dbFor("admin");
  for (const path of paths.slice(0, 6))
    await assertSucceeds(getDoc(doc(db, path)));
  for (const name of [
    "users",
    "doctors",
    "appointments",
    "prescriptions",
    "invoices",
  ])
    await assertSucceeds(getDocs(collection(db, name)));
  for (const path of paths.slice(6)) await assertFails(getDoc(doc(db, path)));
});
test("forged role claims cannot bypass the trusted user document", async () => {
  const db = environment
    .authenticatedContext("p1", { role: "admin", admin: true })
    .firestore();
  await assertFails(getDoc(doc(db, "users/p2")));
  await assertFails(getDocs(collection(db, "users")));
});
for (const uid of ["p1", "d-user1", "admin"]) {
  for (const operation of ["create", "update", "delete"]) {
    test(`${uid} cannot ${operation} any protected records directly`, async () => {
      const db = dbFor(uid);
      for (const path of paths) {
        const ref = doc(
          db,
          operation === "create"
            ? path.replace(/\/[^/]+$/, "/new-document")
            : path,
        );
        if (operation === "create")
          await assertFails(setDoc(ref, { role: "admin", isActive: true }));
        if (operation === "update")
          await assertFails(updateDoc(ref, { role: "admin", patientId: uid }));
        if (operation === "delete") await assertFails(deleteDoc(ref));
      }
    });
  }
}
