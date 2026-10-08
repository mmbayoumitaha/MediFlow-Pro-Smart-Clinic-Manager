import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { ClinicError, requireThat } from "./policy.js";
import { createClinicService } from "./service.js";

initializeApp();
const service = createClinicService(getFirestore(), getAuth());
function command(name) {
  return onCall({ region: "us-central1", maxInstances: 5 }, async (request) => {
    try {
      let data = request.data;
      if (
        data &&
        typeof data === "object" &&
        Object.hasOwn(data, "expectedActorUid")
      ) {
        requireThat(
          request.auth?.uid === data.expectedActorUid,
          "permission-denied",
          "Your sign-in changed. Retry from the current account.",
        );
        const { expectedActorUid, ...commandData } = data;
        data = commandData;
      }
      return await service[name](request.auth?.uid, data);
    } catch (error) {
      if (error instanceof ClinicError)
        throw new HttpsError(error.code, error.message);
      // Never expose database errors or patient records in callable responses/logs.
      logger.error("Clinic command failed", {
        command: name,
        code: error.code ?? "unknown",
      });
      throw new HttpsError(
        "internal",
        "The clinic service could not complete this request.",
      );
    }
  });
}
export const completePatientRegistration = command(
  "completePatientRegistration",
);
export const availableSlots = command("availableSlots");
export const bookAppointment = command("bookAppointment");
export const changeAppointmentStatus = command("changeAppointmentStatus");
export const issueAppointmentInvoice = command("issueAppointmentInvoice");
export const recordInvoicePayment = command("recordInvoicePayment");
export const savePatient = command("savePatient");
export const saveDoctor = command("saveDoctor");
export const removePatient = command("removePatient");
export const removeDoctor = command("removeDoctor");
