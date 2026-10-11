import { FieldValue } from "firebase-admin/firestore";

function requireThat(condition, code, message) {
  if (!condition) throw Object.assign(new Error(message), { code });
}

// Operator-only: never exposed through application signup or callable exports.
export async function provisionAdmin(db, auth, uid, input) {
  requireThat(
    typeof uid === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(uid),
    "invalid-argument",
    "Invalid Auth UID.",
  );
  const fullName = input.fullName?.trim(),
    phone = input.phone?.trim() ?? "";
  requireThat(
    typeof fullName === "string" &&
      fullName.length >= 3 &&
      fullName.length <= 120,
    "invalid-argument",
    "Enter a valid administrator display name.",
  );
  requireThat(
    phone === "" ||
      (phone.length <= 24 && /^\+?([ ()-]*[0-9]){8,15}[ ()-]*$/.test(phone)),
    "invalid-argument",
    "Enter a valid contact number or omit it.",
  );
  const identity = await auth.getUser(uid);
  requireThat(
    !identity.disabled &&
      typeof identity.email === "string" &&
      identity.providerData.some((p) => p.providerId === "password"),
    "failed-precondition",
    "An active email/password Auth identity is required.",
  );
  const email = identity.email.trim().toLowerCase();
  requireThat(
    !email.includes("/"),
    "invalid-argument",
    "Invalid clinic email.",
  );
  return db.runTransaction(async (tx) => {
    const ref = db.doc(`users/${uid}`),
      emailRef = db.doc(`accountEmails/${email}`);
    const [current, revoked, reservation] = await tx.getAll(
      ref,
      db.doc(`revokedUsers/${uid}`),
      emailRef,
    );
    requireThat(
      !revoked.exists &&
        (!current.exists ||
          (current.data().role === "admin" &&
            current.data().email === email)) &&
        (!reservation.exists || reservation.data().userId === uid),
      "failed-precondition",
      "Existing patient, doctor, removed or conflicting identities cannot be promoted.",
    );
    const profile = {
      id: uid,
      email,
      fullName,
      phone,
      role: "admin",
      isActive: true,
      avatarUrl: null,
      gender: null,
      dateOfBirth: null,
      address: null,
      createdAt: current.data()?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.set(ref, profile);
    if (!reservation.exists) tx.set(emailRef, { userId: uid });
    return profile;
  });
}
