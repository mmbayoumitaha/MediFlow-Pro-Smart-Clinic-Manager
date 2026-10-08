import { Timestamp } from "firebase-admin/firestore";
import { DateTime } from "luxon";
import {
  CLINIC_ZONE,
  DURATION_MINUTES,
  cents,
  fields,
  freeSlots,
  identifier,
  instant,
  lifecycleTargets,
  millis,
  ownsVisit,
  phone,
  requireThat,
  text,
} from "./policy.js";

function records(query) {
  return query.docs.map((doc) => ({ ...doc.data(), id: doc.id }));
}
export function serialize(value) {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, serialize(item)]),
    );
  return value;
}

export function createClinicService(
  db,
  auth,
  { now = Date.now, zone = CLINIC_ZONE } = {},
) {
  const lock = db.doc("clinicLocks/current");

  // Every clinic mutation participates in this revision. It serializes competing
  // reservations and future profile changes, including query phantom inserts.
  // This small-clinic reference deliberately favors correctness over throughput.
  async function transaction(uid, action, { enrolling = false } = {}) {
    requireThat(
      typeof uid === "string" && uid.length > 0,
      "unauthenticated",
      "Sign in first.",
    );
    return db.runTransaction(async (tx) => {
      const [revision, actorDoc] = await tx.getAll(
        lock,
        db.doc(`users/${identifier(uid)}`),
      );
      const actor = actorDoc.exists ? { ...actorDoc.data(), id: uid } : null;
      if (!enrolling)
        requireThat(
          actor?.isActive === true &&
            ["patient", "doctor", "admin"].includes(actor.role),
          "permission-denied",
          "Your clinic account is unavailable.",
        );
      const result = await action(tx, actor, now());
      tx.set(lock, { revision: (revision.data()?.revision ?? 0) + 1 });
      return serialize(result);
    });
  }
  async function doctorAndVisits(tx, doctorId) {
    const [doctorDoc, visits] = await Promise.all([
      tx.get(db.doc(`doctors/${doctorId}`)),
      tx.get(db.collection("appointments")),
    ]);
    requireThat(doctorDoc.exists, "not-found", "Doctor unavailable.");
    const doctor = { ...doctorDoc.data(), id: doctorDoc.id };
    const owner = await tx.get(db.doc(`users/${identifier(doctor.userId)}`));
    requireThat(
      owner.exists && owner.data().role === "doctor" && owner.data().isActive,
      "failed-precondition",
      "Doctor unavailable.",
    );
    return { doctor, appointments: records(visits) };
  }
  return {
    async completePatientRegistration(uid, input) {
      fields(input, ["fullName", "phone"]);
      const fullName = text(input.fullName, 3, 100, "name"),
        normalizedPhone = phone(input.phone);
      requireThat(
        typeof uid === "string" && uid.length > 0,
        "unauthenticated",
        "Sign in first.",
      );
      const identity = await auth.getUser(uid);
      requireThat(
        !identity.disabled && typeof identity.email === "string",
        "permission-denied",
        "Email account required.",
      );
      return transaction(
        uid,
        async (tx, existing, time) => {
          if (existing) {
            requireThat(
              existing.role === "patient" &&
                existing.isActive &&
                existing.fullName === fullName &&
                existing.phone === normalizedPhone,
              "already-exists",
              "This account already has a clinic profile.",
            );
            return existing;
          }
          const stamp = Timestamp.fromMillis(time);
          const patient = {
            id: uid,
            email: identity.email.toLowerCase(),
            fullName,
            phone: normalizedPhone,
            role: "patient",
            isActive: true,
            createdAt: stamp,
            updatedAt: stamp,
          };
          tx.create(db.doc(`users/${uid}`), patient);
          return patient;
        },
        { enrolling: true },
      );
    },
    async availableSlots(uid, input) {
      fields(input, ["doctorId", "date"]);
      const doctorId = identifier(input.doctorId);
      // Read-only query uses a transaction for one consistent clock/data view.
      // It does not increment the mutation revision or return patient records.
      requireThat(
        typeof uid === "string" && uid.length > 0,
        "unauthenticated",
        "Sign in first.",
      );
      return db.runTransaction(
        async (tx) => {
          const actor = await tx.get(db.doc(`users/${identifier(uid)}`));
          requireThat(
            actor.exists &&
              actor.data().isActive &&
              actor.data().role === "patient",
            "permission-denied",
            "Patient account required.",
          );
          const { doctor, appointments } = await doctorAndVisits(tx, doctorId);
          return {
            zone,
            startMillis: freeSlots(
              doctor,
              uid,
              appointments,
              input.date,
              now(),
              zone,
            ),
          };
        },
        { readOnly: true },
      );
    },
    async bookAppointment(uid, input) {
      fields(input, [
        "requestId",
        "doctorId",
        "startMillis",
        "expectedFee",
        "expectedSpecialty",
        "reason",
      ]);
      const requestId = identifier(input.requestId),
        doctorId = identifier(input.doctorId);
      const start = instant(input.startMillis),
        fee = cents(input.expectedFee),
        reason = text(input.reason, 0, 1000, "reason") || null;
      return transaction(uid, async (tx, actor, time) => {
        requireThat(
          actor.role === "patient",
          "permission-denied",
          "Patient account required.",
        );
        const ref = db.doc(`appointments/${requestId}`),
          previous = await tx.get(ref);
        if (previous.exists) {
          const visit = previous.data();
          requireThat(
            visit.patientId === uid &&
              visit.doctorId === doctorId &&
              millis(visit.dateTime) === start &&
              cents(visit.fee) === fee &&
              visit.specialty === input.expectedSpecialty &&
              visit.reason === reason,
            "already-exists",
            "This request identifier is already used.",
          );
          return { ...visit, id: ref.id };
        }
        const { doctor, appointments } = await doctorAndVisits(tx, doctorId);
        requireThat(
          cents(doctor.consultationFee) === fee &&
            doctor.specialty === input.expectedSpecialty,
          "failed-precondition",
          "Doctor details changed. Refresh and try again.",
        );
        const date = DateTime.fromMillis(start, { zone }).toISODate();
        requireThat(
          freeSlots(doctor, uid, appointments, date, time, zone).includes(
            start,
          ),
          "failed-precondition",
          "This slot is unavailable.",
        );
        const stamp = Timestamp.fromMillis(time);
        const visit = {
          id: requestId,
          patientId: uid,
          patientName: actor.fullName,
          doctorId,
          doctorUserId: doctor.userId,
          doctorName: doctor.fullName,
          specialty: doctor.specialty,
          dateTime: Timestamp.fromMillis(start),
          durationMinutes: DURATION_MINUTES,
          status: "pending",
          reason,
          fee: doctor.consultationFee,
          paymentStatus: "unpaid",
          createdAt: stamp,
          updatedAt: stamp,
        };
        tx.create(ref, visit);
        tx.set(
          db.doc(`doctorPatients/${doctor.userId}/patients/${uid}`),
          actor,
        );
        return visit;
      });
    },
    async changeAppointmentStatus(uid, input) {
      fields(input, ["appointmentId", "expectedStatus", "targetStatus"]);
      const id = identifier(input.appointmentId);
      return transaction(uid, async (tx, actor, time) => {
        const ref = db.doc(`appointments/${id}`),
          record = await tx.get(ref);
        requireThat(record.exists, "not-found", "Appointment unavailable.");
        const visit = { ...record.data(), id };
        requireThat(
          ownsVisit(actor, visit),
          "permission-denied",
          "You cannot change this appointment.",
        );
        requireThat(
          visit.status === input.expectedStatus,
          "aborted",
          "This appointment changed. Refresh and try again.",
        );
        requireThat(
          lifecycleTargets(actor, visit, time).includes(input.targetStatus),
          "failed-precondition",
          "This status change is not allowed at this time.",
        );
        const updated = {
          ...visit,
          status: input.targetStatus,
          updatedAt: Timestamp.fromMillis(time),
        };
        tx.set(ref, updated);
        return updated;
      });
    },
  };
}
