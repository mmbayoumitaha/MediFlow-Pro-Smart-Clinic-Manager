import { DateTime } from "luxon";
import { isDeepStrictEqual } from "node:util";

export const CLINIC_ZONE = "Africa/Cairo";
export const DURATION_MINUTES = 30;
const days = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
];
const reserved = new Set(["pending", "confirmed", "in_progress"]);

export class ClinicError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
export function requireThat(condition, code, message) {
  if (!condition) throw new ClinicError(code, message);
}
export function fields(input, required, optional = []) {
  requireThat(
    input && typeof input === "object" && !Array.isArray(input),
    "invalid-argument",
    "Expected a command object.",
  );
  requireThat(
    required.every((key) => Object.hasOwn(input, key)) &&
      Object.keys(input).every((key) =>
        [...required, ...optional].includes(key),
      ),
    "invalid-argument",
    "Invalid command fields.",
  );
}
export function identifier(value) {
  requireThat(
    typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value),
    "invalid-argument",
    "Invalid identifier.",
  );
  return value;
}
export function text(value, min, max, label) {
  requireThat(
    typeof value === "string" &&
      value.trim().length >= min &&
      value.trim().length <= max,
    "invalid-argument",
    `Invalid ${label}.`,
  );
  return value.trim();
}
export function phone(value) {
  const result = text(value, 8, 30, "phone");
  requireThat(
    /^\+?[0-9 ()-]+$/.test(result) &&
      result.replace(/\D/g, "").length >= 8 &&
      result.replace(/\D/g, "").length <= 15,
    "invalid-argument",
    "Invalid phone.",
  );
  return result;
}
export function cents(value) {
  requireThat(
    typeof value === "number" &&
      Number.isFinite(value) &&
      value >= 0 &&
      Number.isSafeInteger(Math.round(value * 100)) &&
      Math.abs(value * 100 - Math.round(value * 100)) < 1e-7,
    "invalid-argument",
    "Money must be a nonnegative amount with at most two decimal places.",
  );
  return Math.round(value * 100);
}
export function instant(value) {
  requireThat(
    Number.isSafeInteger(value) && DateTime.fromMillis(value).isValid,
    "invalid-argument",
    "Invalid timestamp.",
  );
  return value;
}
export function millis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  return DateTime.fromISO(value, { setZone: true }).toMillis();
}
function minute(value) {
  if (typeof value !== "string" || !/^\d{2}:\d{2}$/.test(value)) return null;
  const [hour, minutes] = value.split(":").map(Number);
  return hour < 24 && minutes < 60 ? hour * 60 + minutes : null;
}

// Construct each wall-clock candidate separately. Adding elapsed minutes would
// accidentally create nonexistent times or duplicate times at DST boundaries.
export function workingSlots(doctor, date, zone = CLINIC_ZONE) {
  const day = DateTime.fromISO(date, { zone });
  requireThat(
    typeof date === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(date) &&
      day.isValid &&
      day.toISODate() === date,
    "invalid-argument",
    "Invalid clinic date.",
  );
  if (!doctor.isAvailable) return [];
  const result = new Set();
  for (const period of doctor.availability ?? []) {
    if (!period.isActive || period.day !== days[day.weekday - 1]) continue;
    const start = minute(period.startTime),
      end = minute(period.endTime);
    if (start === null || end === null || end <= start) continue;
    for (
      let value = start;
      value + DURATION_MINUTES <= end;
      value += DURATION_MINUTES
    ) {
      const wall = {
        year: day.year,
        month: day.month,
        day: day.day,
        hour: Math.floor(value / 60),
        minute: value % 60,
      };
      const candidate = DateTime.fromObject(wall, { zone });
      if (
        !candidate.isValid ||
        candidate.hour !== wall.hour ||
        candidate.minute !== wall.minute ||
        candidate.toISODate() !== date ||
        candidate.getPossibleOffsets().length !== 1
      )
        continue;
      const finish = candidate.plus({ minutes: DURATION_MINUTES });
      if (
        finish.toISODate() !== date ||
        finish.hour * 60 + finish.minute !== value + DURATION_MINUTES
      )
        continue;
      result.add(candidate.toMillis());
    }
  }
  return [...result].sort((a, b) => a - b);
}
export function overlaps(start, visit) {
  const existing = millis(visit.dateTime);
  return (
    start < existing + visit.durationMinutes * 60000 &&
    existing < start + DURATION_MINUTES * 60000
  );
}
export function freeSlots(
  doctor,
  patientId,
  appointments,
  date,
  now,
  zone = CLINIC_ZONE,
) {
  const today = DateTime.fromMillis(now, { zone }).startOf("day");
  const selected = DateTime.fromISO(date, { zone });
  requireThat(
    selected >= today.plus({ days: 1 }) && selected <= today.plus({ days: 14 }),
    "invalid-argument",
    "Select one of the next 14 clinic dates.",
  );
  return workingSlots(doctor, date, zone).filter(
    (start) =>
      start > now &&
      !appointments.some(
        (visit) =>
          reserved.has(visit.status) &&
          (visit.doctorId === doctor.id || visit.patientId === patientId) &&
          overlaps(start, visit),
      ),
  );
}
export function ownsVisit(actor, visit) {
  return (
    actor.isActive &&
    (actor.role === "admin" ||
      (actor.role === "patient" && actor.id === visit.patientId) ||
      (actor.role === "doctor" && actor.id === visit.doctorUserId))
  );
}
export function lifecycleTargets(actor, visit, now) {
  if (!ownsVisit(actor, visit)) return [];
  const staff = actor.role !== "patient",
    start = millis(visit.dateTime);
  const result = [];
  if (staff && visit.status === "pending" && now <= start)
    result.push("confirmed");
  if (staff && visit.status === "confirmed" && now >= start)
    result.push("in_progress");
  if (staff && visit.status === "in_progress" && now >= start)
    result.push("completed");
  if (["pending", "confirmed"].includes(visit.status) && (staff || now < start))
    result.push("cancelled");
  if (
    staff &&
    ["pending", "confirmed"].includes(visit.status) &&
    now >= start + visit.durationMinutes * 60000
  )
    result.push("no_show");
  return result;
}

export function requireAdmin(actor) {
  requireThat(
    actor?.isActive === true && actor.role === "admin",
    "permission-denied",
    "Administrator account required.",
  );
}
export function boolean(value, label) {
  requireThat(
    typeof value === "boolean",
    "invalid-argument",
    `Invalid ${label}.`,
  );
  return value;
}
export function nullableText(value, max, label) {
  return value == null ? null : text(value, 0, max, label) || null;
}
export function contact(input) {
  fields(input, ["fullName", "phone", "isActive"], ["address"]);
  return {
    fullName: text(input.fullName, 3, 100, "name"),
    phone: phone(input.phone),
    address: nullableText(input.address, 500, "address"),
    isActive: boolean(input.isActive, "account activity"),
  };
}
export function doctorProfile(input) {
  fields(
    input,
    [
      "fullName",
      "email",
      "phone",
      "specialty",
      "consultationFee",
      "experienceYears",
      "availability",
      "isAvailable",
    ],
    ["bio"],
  );
  const email = text(input.email, 3, 254, "email").toLowerCase();
  requireThat(
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email !== "demo@mediflow.com",
    "invalid-argument",
    "Invalid doctor email.",
  );
  requireThat(
    [
      "general_practice",
      "cardiology",
      "dermatology",
      "neurology",
      "orthopedics",
      "pediatrics",
      "ophthalmology",
      "dentistry",
      "gynecology",
      "urology",
      "ent",
      "psychiatry",
      "radiology",
      "laboratory",
    ].includes(input.specialty),
    "invalid-argument",
    "Invalid specialty.",
  );
  cents(input.consultationFee);
  requireThat(
    Number.isInteger(input.experienceYears) &&
      input.experienceYears >= 0 &&
      input.experienceYears <= 80,
    "invalid-argument",
    "Invalid experience.",
  );
  requireThat(
    Array.isArray(input.availability) && input.availability.length <= 28,
    "invalid-argument",
    "Invalid working periods.",
  );
  const availability = input.availability.map((period) => {
    fields(period, ["day", "startTime", "endTime", "isActive"]);
    const start = minute(period.startTime),
      end = minute(period.endTime);
    requireThat(
      days.includes(period.day) &&
        start !== null &&
        end !== null &&
        end - start >= DURATION_MINUTES,
      "invalid-argument",
      "Each working period must allow a same-day 30-minute visit.",
    );
    return {
      day: period.day,
      startTime: period.startTime,
      endTime: period.endTime,
      isActive: boolean(period.isActive, "working period"),
    };
  });
  for (const day of days) {
    const periods = availability
      .filter((period) => period.day === day && period.isActive)
      .sort((a, b) => a.startTime.localeCompare(b.startTime));
    requireThat(
      periods.every(
        (period, index) =>
          index === 0 || period.startTime >= periods[index - 1].endTime,
      ),
      "invalid-argument",
      "Active working periods must not overlap.",
    );
  }
  const isAvailable = boolean(input.isAvailable, "booking availability");
  requireThat(
    !isAvailable || availability.some((period) => period.isActive),
    "invalid-argument",
    "Add an active working period before enabling booking.",
  );
  return {
    fullName: text(input.fullName, 3, 100, "name"),
    email,
    phone: phone(input.phone),
    specialty: input.specialty,
    consultationFee: input.consultationFee,
    experienceYears: input.experienceYears,
    availability,
    isAvailable,
    bio: nullableText(input.bio, 2000, "biography"),
  };
}
export const patientEditable = [
  "id",
  "fullName",
  "phone",
  "address",
  "isActive",
];
export const doctorEditable = [
  "id",
  "userId",
  "fullName",
  "email",
  "phone",
  "bio",
  "specialty",
  "consultationFee",
  "experienceYears",
  "isAvailable",
  "availability",
];
export function sameEditable(current, expected, keys) {
  fields(
    expected,
    keys.filter((key) => !["address", "bio"].includes(key)),
    keys.filter((key) => ["address", "bio"].includes(key)),
  );
  return keys.every((key) =>
    isDeepStrictEqual(current[key] ?? null, expected[key] ?? null),
  );
}
export function validateInvoice(invoice, now) {
  const subtotal = cents(invoice.subtotal),
    total = cents(invoice.total),
    tax = cents(invoice.tax),
    discount = cents(invoice.discount);
  requireThat(
    Array.isArray(invoice.items) && invoice.items.length > 0,
    "failed-precondition",
    "Invoice items are invalid.",
  );
  let sum = 0;
  for (const item of invoice.items) {
    requireThat(
      typeof item.description === "string" &&
        item.description.trim().length > 0 &&
        Number.isSafeInteger(item.quantity) &&
        item.quantity >= 1 &&
        cents(item.total) === cents(item.unitPrice) * item.quantity,
      "failed-precondition",
      "Invoice items are invalid.",
    );
    sum += cents(item.total);
    requireThat(
      Number.isSafeInteger(sum),
      "failed-precondition",
      "Invoice total is invalid.",
    );
  }
  const issued = millis(invoice.issuedDate);
  requireThat(
    Number.isFinite(issued) &&
      issued <= now &&
      subtotal === sum &&
      total === subtotal + tax - discount &&
      total > 0,
    "failed-precondition",
    "Invoice totals or issue date are invalid.",
  );
}
export function paymentTransition(invoice, expected, target, method, now) {
  requireThat(
    invoice.paymentStatus === expected,
    "aborted",
    "This invoice changed. Refresh and try again.",
  );
  validateInvoice(invoice, now);
  const settle =
    target === "paid" &&
    ["unpaid", "partial"].includes(expected) &&
    ["cash", "card", "bankTransfer"].includes(method);
  const paid = invoice.paidDate == null ? NaN : millis(invoice.paidDate);
  const refund =
    target === "refunded" &&
    expected === "paid" &&
    Number.isFinite(paid) &&
    paid >= millis(invoice.issuedDate) &&
    paid <= now;
  requireThat(
    settle || refund,
    "failed-precondition",
    "Only full settlement or full refund can be recorded.",
  );
}
export function retainReservations(
  current,
  updated,
  visits,
  now,
  zone = CLINIC_ZONE,
) {
  if (isDeepStrictEqual(current.availability, updated.availability)) return;
  for (const visit of visits.filter(
    (visit) =>
      visit.doctorId === current.id &&
      reserved.has(visit.status) &&
      millis(visit.dateTime) >= now,
  )) {
    const start = millis(visit.dateTime),
      date = DateTime.fromMillis(start, { zone }).toISODate();
    requireThat(
      visit.durationMinutes === DURATION_MINUTES &&
        workingSlots({ ...updated, isAvailable: true }, date, zone).includes(
          start,
        ),
      "aborted",
      "Working periods must retain existing future reservations.",
    );
  }
}
