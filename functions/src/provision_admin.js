import { Timestamp } from "firebase-admin/firestore";
import { identifier, requireThat, text, phone } from "./policy.js";

// This helper is deliberately absent from the callable exports. Only a trusted
// operator with Admin SDK credentials may provision the initial administrator.
export async function provisionAdmin(
  db,
  auth,
  uid,
  input,
  { now = Date.now } = {},
) {
  identifier(uid);
  const identity = await auth.getUser(uid);
  requireThat(
    !identity.disabled && typeof identity.email === "string",
    "failed-precondition",
    "An active email/password Auth identity is required.",
  );
  const fullName = text(input.fullName, 3, 100, "name"),
    normalizedPhone = phone(input.phone);
  return db.runTransaction(async (tx) => {
    const lock = db.doc("clinicLocks/current"),
      ref = db.doc(`users/${uid}`);
    const [revision, current, revoked, staff] = await tx.getAll(
      lock,
      ref,
      db.doc(`revokedUsers/${uid}`),
      db.doc(`staffProvisioning/${uid}`),
    );
    requireThat(
      !revoked.exists &&
        !staff.exists &&
        (!current.exists || current.data().role === "admin"),
      "failed-precondition",
      "Existing patient, doctor or removed identities cannot be promoted.",
    );
    const stamp = Timestamp.fromMillis(now());
    const admin = {
      id: uid,
      email: identity.email.toLowerCase(),
      fullName,
      phone: normalizedPhone,
      role: "admin",
      isActive: true,
      createdAt: current.data()?.createdAt ?? stamp,
      updatedAt: stamp,
    };
    tx.set(ref, admin);
    tx.set(lock, { revision: (revision.data()?.revision ?? 0) + 1 });
    return admin;
  });
}
