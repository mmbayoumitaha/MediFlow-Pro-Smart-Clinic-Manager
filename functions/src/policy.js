import { DateTime } from "luxon";

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
