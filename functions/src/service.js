import { Timestamp } from "firebase-admin/firestore";
import { DateTime } from "luxon";
import { randomBytes } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
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
  requireAdmin,
  contact,
  doctorProfile,
  patientEditable,
  doctorEditable,
  sameEditable,
  paymentTransition,
  validateInvoice,
  retainReservations,
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
          const [revoked, staff] = await tx.getAll(
            db.doc(`revokedUsers/${uid}`),
            db.doc(`staffProvisioning/${uid}`),
          );
          requireThat(
            !revoked.exists && !staff.exists,
            "permission-denied",
            "This identity cannot self-enroll.",
          );
          const [doctorIdentity, reservedIdentity] = await Promise.all([
            tx.get(db.doc(`doctors/${uid}`)),
            tx.get(
              db.collection("staffProvisioning").where("doctorId", "==", uid),
            ),
          ]);
          requireThat(
            !doctorIdentity.exists && reservedIdentity.empty,
            "already-exists",
            "Clinic identity unavailable.",
          );
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
    async issueAppointmentInvoice(uid, input) {
      fields(input, ["appointmentId", "invoiceId"]);
      const visitId = identifier(input.appointmentId),
        invoiceId = identifier(input.invoiceId);
      return transaction(uid, async (tx, actor, time) => {
        requireAdmin(actor);
        const [linked, visitDoc, invoiceDoc] = await Promise.all([
          tx.get(
            db.collection("invoices").where("appointmentId", "==", visitId),
          ),
          tx.get(db.doc(`appointments/${visitId}`)),
          tx.get(db.doc(`invoices/${invoiceId}`)),
        ]);
        requireThat(
          linked.size <= 1,
          "aborted",
          "This visit has multiple invoices.",
        );
        if (linked.size === 1)
          return { ...linked.docs[0].data(), id: linked.docs[0].id };
        requireThat(visitDoc.exists, "not-found", "Appointment unavailable.");
        requireThat(
          !invoiceDoc.exists,
          "already-exists",
          "Invoice identifier unavailable.",
        );
        const visit = visitDoc.data();
        requireThat(
          visit.status === "completed" && visit.paymentStatus === "unpaid",
          "failed-precondition",
          "Only an unpaid completed visit can receive an invoice.",
        );
        const stamp = Timestamp.fromMillis(time);
        const invoice = {
          id: invoiceId,
          patientId: visit.patientId,
          patientName: visit.patientName,
          appointmentId: visitId,
          items: [
            {
              description: `Consultation with ${visit.doctorName}`,
              quantity: 1,
              unitPrice: visit.fee,
              total: visit.fee,
            },
          ],
          subtotal: visit.fee,
          tax: 0,
          discount: 0,
          total: visit.fee,
          paymentStatus: "unpaid",
          paymentMethod: null,
          issuedDate: stamp,
          paidDate: null,
          createdAt: stamp,
        };
        validateInvoice(invoice, time);
        tx.create(db.doc(`invoices/${invoiceId}`), invoice);
        return invoice;
      });
    },
    async recordInvoicePayment(uid, input) {
      fields(
        input,
        ["invoiceId", "expectedPayment", "targetPayment"],
        ["method"],
      );
      const id = identifier(input.invoiceId);
      return transaction(uid, async (tx, actor, time) => {
        requireAdmin(actor);
        const ref = db.doc(`invoices/${id}`),
          invoiceDoc = await tx.get(ref);
        requireThat(invoiceDoc.exists, "not-found", "Invoice unavailable.");
        const invoice = { ...invoiceDoc.data(), id };
        paymentTransition(
          invoice,
          input.expectedPayment,
          input.targetPayment,
          input.method,
          time,
        );
        let visitRef = null,
          visit = null;
        if (invoice.appointmentId != null) {
          visitRef = db.doc(
            `appointments/${identifier(invoice.appointmentId)}`,
          );
          const [visitDoc, linked] = await Promise.all([
            tx.get(visitRef),
            tx.get(
              db
                .collection("invoices")
                .where("appointmentId", "==", invoice.appointmentId),
            ),
          ]);
          requireThat(
            visitDoc.exists &&
              visitDoc.data().patientId === invoice.patientId &&
              linked.size === 1,
            "aborted",
            "Invoice appointment linkage is invalid.",
          );
          visit = visitDoc.data();
        }
        const stamp = Timestamp.fromMillis(time),
          updated = {
            ...invoice,
            paymentStatus: input.targetPayment,
            paymentMethod:
              input.targetPayment === "paid"
                ? input.method
                : (invoice.paymentMethod ?? null),
            paidDate: input.targetPayment === "paid" ? stamp : invoice.paidDate,
          };
        tx.set(ref, updated);
        if (visitRef)
          tx.set(visitRef, {
            ...visit,
            paymentStatus: input.targetPayment,
            updatedAt: stamp,
          });
        return updated;
      });
    },
    async savePatient(uid, input) {
      fields(input, ["expected", "contact"]);
      const id = identifier(input.expected?.id),
        edited = contact(input.contact);
      return transaction(uid, async (tx, actor, time) => {
        const [patientDoc, visits] = await Promise.all([
          tx.get(db.doc(`users/${id}`)),
          tx.get(db.collection("appointments")),
        ]);
        requireThat(
          patientDoc.exists && patientDoc.data().role === "patient",
          "not-found",
          "Patient unavailable.",
        );
        const patient = { ...patientDoc.data(), id };
        requireThat(
          actor.role === "admin" ||
            (actor.role === "patient" &&
              actor.id === id &&
              edited.isActive === patient.isActive),
          "permission-denied",
          "You cannot edit this patient.",
        );
        requireThat(
          sameEditable(patient, input.expected, patientEditable),
          "aborted",
          "This profile changed. Reopen the form.",
        );
        const updated = {
          ...patient,
          ...edited,
          updatedAt: Timestamp.fromMillis(time),
        };
        tx.set(db.doc(`users/${id}`), updated);
        const doctors = new Set(
          records(visits)
            .filter((visit) => visit.patientId === id)
            .map((visit) => identifier(visit.doctorUserId)),
        );
        for (const doctor of doctors)
          tx.set(db.doc(`doctorPatients/${doctor}/patients/${id}`), updated);
        return updated;
      });
    },
    async saveDoctor(uid, input) {
      fields(input, ["expected", "profile"], ["newDoctorId", "newUserId"]);
      const edited = doctorProfile(input.profile);
      if (input.expected === null) return createDoctor(uid, input, edited);
      requireThat(
        input.newDoctorId == null && input.newUserId == null,
        "invalid-argument",
        "Profile identities cannot change.",
      );
      const id = identifier(input.expected?.id);
      return transaction(uid, async (tx, actor, time) => {
        const [doctorDoc, visits, profiles] = await Promise.all([
          tx.get(db.doc(`doctors/${id}`)),
          tx.get(db.collection("appointments")),
          tx.get(db.collection("doctors").where("userId", "==", uid)),
        ]);
        requireThat(doctorDoc.exists, "not-found", "Doctor unavailable.");
        const current = { ...doctorDoc.data(), id };
        requireThat(
          actor.role === "admin" ||
            (actor.role === "doctor" &&
              current.userId === uid &&
              profiles.size === 1),
          "permission-denied",
          "You cannot edit this doctor.",
        );
        requireThat(
          sameEditable(current, input.expected, doctorEditable),
          "aborted",
          "This profile changed. Reopen the form.",
        );
        requireThat(
          edited.email === current.email,
          "invalid-argument",
          "The sign-in email cannot change here.",
        );
        const ownerRef = db.doc(`users/${identifier(current.userId)}`),
          owner = await tx.get(ownerRef);
        requireThat(
          owner.exists && owner.data().role === "doctor",
          "failed-precondition",
          "Doctor account unavailable.",
        );
        const updated = { ...current, ...edited };
        retainReservations(current, updated, records(visits), time, zone);
        tx.set(db.doc(`doctors/${id}`), updated);
        tx.set(ownerRef, {
          ...owner.data(),
          fullName: edited.fullName,
          phone: edited.phone,
          updatedAt: Timestamp.fromMillis(time),
        });
        return updated;
      });
    },
    async removePatient(uid, input) {
      fields(input, ["expected"]);
      const id = identifier(input.expected?.id);
      return transaction(uid, async (tx, actor, time) => {
        requireAdmin(actor);
        const [patientDoc, visits, prescriptions, invoices] = await Promise.all(
          [
            tx.get(db.doc(`users/${id}`)),
            tx.get(db.collection("appointments").where("patientId", "==", id)),
            tx.get(db.collection("prescriptions").where("patientId", "==", id)),
            tx.get(db.collection("invoices").where("patientId", "==", id)),
          ],
        );
        requireThat(
          patientDoc.exists && patientDoc.data().role === "patient",
          "not-found",
          "Patient unavailable.",
        );
        requireThat(
          sameEditable(
            { ...patientDoc.data(), id },
            input.expected,
            patientEditable,
          ),
          "aborted",
          "This profile changed. Reopen the form.",
        );
        requireThat(
          visits.empty && prescriptions.empty && invoices.empty,
          "failed-precondition",
          "This patient has clinic records. Deactivate the account instead.",
        );
        tx.delete(db.doc(`users/${id}`));
        tx.set(db.doc(`revokedUsers/${id}`), {
          revokedAt: Timestamp.fromMillis(time),
        });
        return null;
      });
    },
    async removeDoctor(uid, input) {
      fields(input, ["expected"]);
      const id = identifier(input.expected?.id);
      return transaction(uid, async (tx, actor, time) => {
        requireAdmin(actor);
        const [doctorDoc, visits, prescriptions] = await Promise.all([
          tx.get(db.doc(`doctors/${id}`)),
          tx.get(db.collection("appointments").where("doctorId", "==", id)),
          tx.get(db.collection("prescriptions").where("doctorId", "==", id)),
        ]);
        requireThat(doctorDoc.exists, "not-found", "Doctor unavailable.");
        const current = { ...doctorDoc.data(), id };
        requireThat(
          sameEditable(current, input.expected, doctorEditable),
          "aborted",
          "This profile changed. Reopen the form.",
        );
        requireThat(
          visits.empty && prescriptions.empty,
          "failed-precondition",
          "This doctor has clinic records. Disable booking instead.",
        );
        const userId = identifier(current.userId);
        const [owner, linked] = await Promise.all([
          tx.get(db.doc(`users/${userId}`)),
          tx.get(db.collection("doctors").where("userId", "==", userId)),
        ]);
        requireThat(
          owner.exists && owner.data().role === "doctor" && linked.size === 1,
          "failed-precondition",
          "Doctor account linkage is invalid.",
        );
        tx.delete(db.doc(`doctors/${id}`));
        tx.delete(db.doc(`users/${userId}`));
        tx.set(db.doc(`revokedUsers/${userId}`), {
          revokedAt: Timestamp.fromMillis(time),
        });
        return null;
      });
    },
  };

  async function createDoctor(uid, input, profile) {
    const requestedDoctorId = identifier(input.newDoctorId),
      requestedUserId = identifier(input.newUserId);
    requireThat(
      requestedDoctorId !== requestedUserId,
      "invalid-argument",
      "Doctor and account identities must differ.",
    );
    // Auth cannot join a Firestore transaction. A private durable request records
    // ownership and an unpredictable Auth display-name marker for safe recovery.
    // No privileged clinic profile exists until Auth creation has succeeded.
    const request = await transaction(uid, async (tx, actor, time) => {
      requireAdmin(actor);
      const [staff, users, doctors] = await Promise.all([
        tx.get(db.collection("staffProvisioning")),
        tx.get(db.collection("users")),
        tx.get(db.collection("doctors")),
      ]);
      const previous = records(staff).find(
        (item) => item.profile.email === profile.email,
      );
      if (previous) {
        requireThat(
          previous.ownerId === uid &&
            isDeepStrictEqual(previous.profile, profile),
          "already-exists",
          "This email already has a provisioning request. Retry the original details.",
        );
        requireThat(
          !previous.revoked,
          "permission-denied",
          "This staff account was removed.",
        );
        return previous;
      }
      const identities = new Set([
        ...records(users).map((user) => user.id),
        ...records(doctors).flatMap((doctor) => [doctor.id, doctor.userId]),
        ...records(staff).flatMap((request) => [
          request.userId,
          request.doctorId,
        ]),
      ]);
      requireThat(
        !identities.has(requestedDoctorId) &&
          !identities.has(requestedUserId) &&
          !records(users).some(
            (user) => user.email?.toLowerCase() === profile.email,
          ) &&
          !records(doctors).some((doctor) => doctor.email === profile.email),
        "already-exists",
        "Doctor email or identity unavailable.",
      );
      const revoked = await tx.getAll(
        db.doc(`revokedUsers/${requestedUserId}`),
        db.doc(`revokedUsers/${requestedDoctorId}`),
      );
      requireThat(
        revoked.every((record) => !record.exists),
        "permission-denied",
        "This account identity was removed.",
      );
      const pending = {
        id: requestedUserId,
        userId: requestedUserId,
        doctorId: requestedDoctorId,
        ownerId: uid,
        profile,
        marker: `MediFlow ${randomBytes(24).toString("hex")}`,
        completed: false,
        createdAt: Timestamp.fromMillis(time),
      };
      tx.create(db.doc(`staffProvisioning/${requestedUserId}`), pending);
      return pending;
    });
    if (!request.completed) {
      let identity;
      try {
        identity = await auth.createUser({
          uid: request.userId,
          email: profile.email,
          password: randomBytes(48).toString("base64url"),
          displayName: request.marker,
        });
      } catch (error) {
        if (
          !["auth/uid-already-exists", "auth/email-already-exists"].includes(
            error.code,
          )
        )
          throw error;
        try {
          identity = await auth.getUser(request.userId);
        } catch (lookupError) {
          requireThat(
            lookupError.code !== "auth/user-not-found",
            "already-exists",
            "The email already belongs to an authentication account.",
          );
          throw lookupError;
        }
      }
      requireThat(
        !identity.disabled &&
          identity.email?.toLowerCase() === profile.email &&
          identity.displayName === request.marker,
        "already-exists",
        "This authentication identity cannot be provisioned.",
      );
    }
    return transaction(uid, async (tx, actor, time) => {
      requireAdmin(actor);
      const [pendingDoc, doctorDoc, userDoc, revoked] = await tx.getAll(
        db.doc(`staffProvisioning/${request.userId}`),
        db.doc(`doctors/${request.doctorId}`),
        db.doc(`users/${request.userId}`),
        db.doc(`revokedUsers/${request.userId}`),
      );
      const pending = pendingDoc.data();
      requireThat(
        pendingDoc.exists &&
          pending.ownerId === uid &&
          isDeepStrictEqual(pending.profile, profile) &&
          !revoked.exists,
        "permission-denied",
        "Provisioning request unavailable.",
      );
      if (pending.completed) {
        requireThat(
          doctorDoc.exists &&
            userDoc.exists &&
            userDoc.data().role === "doctor",
          "failed-precondition",
          "Doctor account unavailable.",
        );
        return { ...doctorDoc.data(), id: doctorDoc.id };
      }
      requireThat(
        !doctorDoc.exists && !userDoc.exists,
        "already-exists",
        "Doctor identity unavailable.",
      );
      const stamp = Timestamp.fromMillis(time);
      const doctor = {
        ...profile,
        id: request.doctorId,
        userId: request.userId,
        rating: 0,
        totalReviews: 0,
        createdAt: stamp,
      };
      const user = {
        id: request.userId,
        email: profile.email,
        fullName: profile.fullName,
        phone: profile.phone,
        role: "doctor",
        isActive: true,
        createdAt: stamp,
        updatedAt: stamp,
      };
      tx.create(db.doc(`doctors/${request.doctorId}`), doctor);
      tx.create(db.doc(`users/${request.userId}`), user);
      tx.update(pendingDoc.ref, { completed: true });
      return doctor;
    });
  }
}
