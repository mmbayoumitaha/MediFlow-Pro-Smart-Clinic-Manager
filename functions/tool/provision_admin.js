import { parseArgs } from "node:util";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { provisionAdmin } from "../src/provision_admin.js";

const { values } = parseArgs({
  options: {
    project: { type: "string" },
    uid: { type: "string" },
    name: { type: "string" },
    phone: { type: "string" },
  },
});
if (![values.project, values.uid, values.name, values.phone].every(Boolean)) {
  console.error(
    "Usage: node functions/tool/provision_admin.js --project PROJECT_ID --uid AUTH_UID --name 'Full Name' --phone '+201000000000'",
  );
  process.exitCode = 1;
} else {
  const emulated = Boolean(
    process.env.FIRESTORE_EMULATOR_HOST ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
  );
  if (
    (emulated || values.project.startsWith("demo-")) &&
    (!process.env.FIRESTORE_EMULATOR_HOST ||
      !process.env.FIREBASE_AUTH_EMULATOR_HOST ||
      !values.project.startsWith("demo-"))
  ) {
    throw new Error(
      "Emulator provisioning requires both emulators and a demo- project.",
    );
  }
  const app = initializeApp({ projectId: values.project });
  const db = getFirestore(app);
  try {
    await provisionAdmin(db, getAuth(app), values.uid, {
      fullName: values.name,
      phone: values.phone,
    });
    console.log("Administrator profile provisioned.");
  } catch (error) {
    console.error(`Provisioning failed (${error.code ?? "unknown"}).`);
    process.exitCode = 1;
  } finally {
    await db.terminate();
    await deleteApp(app);
  }
}
