import assert from "node:assert/strict";
import { test } from "node:test";
import { DateTime } from "luxon";
import {
  CLINIC_ZONE,
  ClinicError,
  cents,
  fields,
  freeSlots,
  identifier,
  lifecycleTargets,
  workingSlots,
} from "../src/policy.js";

const epoch = (iso) => DateTime.fromISO(iso, { zone: CLINIC_ZONE }).toMillis();
const doctor = {
  id: "doctor-one",
  isAvailable: true,
  availability: [
    { day: "monday", startTime: "09:00", endTime: "11:00", isActive: true },
  ],
};
const visit = {
  id: "visit",
  patientId: "patient-one",
  doctorId: doctor.id,
  doctorUserId: "doctor-user",
  dateTime: "2026-10-12T06:00:00Z",
  durationMinutes: 30,
  status: "pending",
};
const patient = { id: "patient-one", role: "patient", isActive: true };
const staff = { id: "doctor-user", role: "doctor", isActive: true };

test("clinic slots are UTC instants corresponding to Cairo wall times, ending at closing", () => {
  assert.deepEqual(
    workingSlots(doctor, "2026-10-12"),
    [9, 9.5, 10, 10.5].map((hour) =>
      epoch(
        `2026-10-12T${Math.floor(hour).toString().padStart(2, "0")}:${hour % 1 ? "30" : "00"}:00`,
      ),
    ),
  );
  assert.equal(
    workingSlots({ ...doctor, isAvailable: false }, "2026-10-12").length,
    0,
  );
});
test("overlapping periods deduplicate and malformed periods produce no slots", () => {
  const periods = doctor.availability;
  assert.equal(
    workingSlots(
      {
        ...doctor,
        availability: [
          ...periods,
          ...periods,
          { ...periods[0], startTime: "9:00" },
          { ...periods[0], endTime: "08:00" },
        ],
      },
      "2026-10-12",
    ).length,
    4,
  );
  assert.throws(() => workingSlots(doctor, "2026-02-30"), ClinicError);
});
test("Cairo DST start never manufactures nonexistent midnight slots", () => {
  const slots = workingSlots(
    {
      ...doctor,
      availability: [
        { day: "friday", startTime: "00:00", endTime: "02:00", isActive: true },
      ],
    },
    "2026-04-24",
  );
  assert.deepEqual(
    slots.map((value) =>
      DateTime.fromMillis(value, { zone: CLINIC_ZONE }).toFormat("HH:mm"),
    ),
    ["01:00", "01:30"],
  );
});
test("Cairo DST end excludes ambiguous instants", () => {
  const slots = workingSlots(
    {
      ...doctor,
      availability: [
        {
          day: "thursday",
          startTime: "22:00",
          endTime: "23:59",
          isActive: true,
        },
      ],
    },
    "2026-10-29",
  );
  // 23:00 and 23:30 occur twice; 22:30 is safe and ends at the first 23:00.
  assert.deepEqual(
    slots.map((value) =>
      DateTime.fromMillis(value, { zone: CLINIC_ZONE }).toFormat("HH:mm"),
    ),
    ["22:00", "22:30"],
  );
});
test("free slots protect both doctor occupancy and patient visits at other doctors", () => {
  const otherDoctorVisit = {
    ...visit,
    doctorId: "other",
    dateTime: "2026-10-12T06:30:00Z",
  };
  const available = freeSlots(
    doctor,
    patient.id,
    [visit, otherDoctorVisit],
    "2026-10-12",
    epoch("2026-10-11T20:00"),
  );
  assert.deepEqual(available, [
    epoch("2026-10-12T10:00"),
    epoch("2026-10-12T10:30"),
  ]);
  assert.equal(
    freeSlots(
      doctor,
      patient.id,
      [{ ...visit, status: "cancelled" }],
      "2026-10-12",
      epoch("2026-10-11T20:00"),
    ).length,
    4,
  );
});
test("half-open intervals support adjoining visits but reject partial overlaps", () => {
  const shifted = { ...visit, dateTime: "2026-10-12T06:15:00Z" };
  const available = freeSlots(
    doctor,
    patient.id,
    [shifted],
    "2026-10-12",
    epoch("2026-10-11T20:00"),
  );
  assert.deepEqual(available, [
    epoch("2026-10-12T10:00"),
    epoch("2026-10-12T10:30"),
  ]);
});
test("booking horizon uses Cairo dates across month/year boundaries", () => {
  const selectedDoctor = {
    ...doctor,
    availability: [
      { day: "thursday", startTime: "09:00", endTime: "10:00", isActive: true },
    ],
  };
  assert.equal(
    freeSlots(
      selectedDoctor,
      patient.id,
      [],
      "2027-01-07",
      epoch("2026-12-31T23:59"),
    ).length,
    2,
  );
  for (const date of ["2026-12-31", "2027-01-15", "invalid"]) {
    assert.throws(
      () =>
        freeSlots(
          selectedDoctor,
          patient.id,
          [],
          date,
          epoch("2026-12-31T23:59"),
        ),
      ClinicError,
    );
  }
});
test("lifecycle honors patient/staff ownership and exact start/end boundaries", () => {
  const start = Date.parse(visit.dateTime);
  assert.deepEqual(lifecycleTargets(patient, visit, start - 1), ["cancelled"]);
  assert.deepEqual(lifecycleTargets(patient, visit, start), []);
  assert.deepEqual(lifecycleTargets(staff, visit, start), [
    "confirmed",
    "cancelled",
  ]);
  assert.deepEqual(lifecycleTargets(staff, visit, start + 30 * 60000), [
    "cancelled",
    "no_show",
  ]);
  assert.deepEqual(
    lifecycleTargets(staff, { ...visit, status: "confirmed" }, start),
    ["in_progress", "cancelled"],
  );
  assert.deepEqual(
    lifecycleTargets(staff, { ...visit, status: "in_progress" }, start),
    ["completed"],
  );
  for (const status of ["completed", "cancelled", "no_show"])
    assert.deepEqual(lifecycleTargets(staff, { ...visit, status }, start), []);
  for (const actor of [
    { ...patient, id: "foreign" },
    { ...staff, id: "other" },
    { ...staff, isActive: false },
  ]) {
    assert.deepEqual(lifecycleTargets(actor, visit, start), []);
  }
});
test("commands reject extra identity/role fields, unsafe paths and invalid money", () => {
  assert.throws(
    () => fields({ doctorId: "one", actor: { role: "admin" } }, ["doctorId"]),
    ClinicError,
  );
  for (const id of ["", "../user", "foo/bar", "a".repeat(129), null])
    assert.throws(() => identifier(id), ClinicError);
  for (const money of [NaN, Infinity, -1, 1.001, Number.MAX_SAFE_INTEGER, "12"])
    assert.throws(() => cents(money), ClinicError);
  assert.equal(cents(12.34), 1234);
});
