import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../domain/entities.dart';
import '../domain/app_enums.dart';
import '../domain/profile_policy.dart';

Future<void> editPatientProfile(BuildContext context, ClinicUser patient) =>
    showDialog(context: context, builder: (_) => _PatientForm(patient));
Future<void> editDoctorProfile(BuildContext context, Doctor? doctor) =>
    showDialog(context: context, builder: (_) => _DoctorForm(doctor));
Future<void> removeProfile(
  BuildContext context,
  WidgetRef ref, {
  ClinicUser? patient,
  Doctor? doctor,
}) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete unused demo profile?'),
      content: const Text(
        'Deletion is allowed only when no appointments, prescriptions or invoices reference the profile. Historical clinic records are kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep profile'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete profile'),
        ),
      ],
    ),
  );
  if (approved != true || !context.mounted) return;
  final model = ref.read(profileActionsProvider.notifier);
  final ok = patient != null
      ? await model.removePatient(patient)
      : await model.removeDoctor(doctor!);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Unused demo profile deleted.'
            : ref.read(profileActionsProvider).error ??
                  'Another update is in progress.',
      ),
    ),
  );
}

class _PatientForm extends ConsumerStatefulWidget {
  final ClinicUser patient;
  const _PatientForm(this.patient);
  @override
  ConsumerState<_PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends ConsumerState<_PatientForm> {
  late final TextEditingController name = TextEditingController(
    text: widget.patient.fullName,
  );
  late final TextEditingController phone = TextEditingController(
    text: widget.patient.phone,
  );
  late final TextEditingController address = TextEditingController(
    text: widget.patient.address,
  );
  late bool active = widget.patient.isActive;
  String? error;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final ok = await ref
        .read(profileActionsProvider.notifier)
        .patient(
          widget.patient,
          ContactInput(
            fullName: name.text,
            phone: phone.text,
            address: address.text,
            isActive: active,
          ),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () => error =
            ref.read(profileActionsProvider).error ??
            'Another update is in progress.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(profileActionsProvider).isSubmitting;
    final admin = ref.watch(authProvider).currentUser?.role == UserRole.admin;
    return AlertDialog(
      title: const Text('Edit patient profile'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.patient.email),
              TextField(
                key: const ValueKey('profile-name'),
                controller: name,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                key: const ValueKey('profile-phone'),
                controller: phone,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                key: const ValueKey('profile-address'),
                controller: address,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                ),
              ),
              if (admin)
                SwitchListTile(
                  title: const Text('Account active'),
                  subtitle: const Text(
                    'Inactive patients cannot sign in or book. Existing clinic records remain.',
                  ),
                  value: active,
                  onChanged: busy ? null : (v) => setState(() => active = v),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('profile-save'),
          onPressed: busy ? null : save,
          child: const Text('Save profile'),
        ),
      ],
    );
  }
}

class _Period {
  final key = UniqueKey();
  DayOfWeek day;
  bool active;
  final TextEditingController start, end;
  _Period(AvailabilitySlot slot)
    : day = slot.day,
      active = slot.isActive,
      start = TextEditingController(text: slot.startTime),
      end = TextEditingController(text: slot.endTime);
  AvailabilitySlot get slot => AvailabilitySlot(
    day: day,
    startTime: start.text.trim(),
    endTime: end.text.trim(),
    isActive: active,
  );
  void dispose() {
    start.dispose();
    end.dispose();
  }
}

class _DoctorForm extends ConsumerStatefulWidget {
  final Doctor? doctor;
  const _DoctorForm(this.doctor);
  @override
  ConsumerState<_DoctorForm> createState() => _DoctorFormState();
}

class _DoctorFormState extends ConsumerState<_DoctorForm> {
  late final TextEditingController name = TextEditingController(
    text: widget.doctor?.fullName,
  );
  late final TextEditingController email = TextEditingController(
    text: widget.doctor?.email,
  );
  late final TextEditingController phone = TextEditingController(
    text: widget.doctor?.phone,
  );
  late final TextEditingController bio = TextEditingController(
    text: widget.doctor?.bio,
  );
  late final TextEditingController fee = TextEditingController(
    text: widget.doctor?.consultationFee.toStringAsFixed(2) ?? '0.00',
  );
  late final TextEditingController experience = TextEditingController(
    text: '${widget.doctor?.experienceYears ?? 0}',
  );
  late MedicalSpecialty specialty =
      widget.doctor?.specialty ?? MedicalSpecialty.generalPractice;
  late bool available = widget.doctor?.isAvailable ?? false;
  late final List<_Period> periods =
      (widget.doctor?.availability ?? const <AvailabilitySlot>[])
          .map(_Period.new)
          .toList();
  final retiredPeriods = <_Period>[];
  String? error;
  @override
  void dispose() {
    for (final c in [name, email, phone, bio, fee, experience]) {
      c.dispose();
    }
    for (final p in [...periods, ...retiredPeriods]) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final amount = double.tryParse(fee.text.trim());
    final years = int.tryParse(experience.text.trim());
    if (amount == null || years == null) {
      setState(
        () => error =
            'Enter a valid consultation fee and whole years of experience.',
      );
      return;
    }
    final ok = await ref
        .read(profileActionsProvider.notifier)
        .doctor(
          widget.doctor,
          DoctorInput(
            fullName: name.text,
            email: email.text,
            phone: phone.text,
            bio: bio.text,
            specialty: specialty,
            consultationFee: amount,
            experienceYears: years,
            availability: periods.map((p) => p.slot).toList(),
            isAvailable: available,
          ),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(
        () => error =
            ref.read(profileActionsProvider).error ??
            'Another update is in progress.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(profileActionsProvider).isSubmitting;
    return AlertDialog(
      title: Text(
        widget.doctor == null
            ? 'Add demo doctor'
            : 'Edit doctor profile & availability',
      ),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('profile-name'),
                controller: name,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                key: const ValueKey('profile-email'),
                controller: email,
                enabled: !busy && widget.doctor == null,
                decoration: const InputDecoration(labelText: 'Sign-in email'),
              ),
              TextField(
                key: const ValueKey('profile-phone'),
                controller: phone,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: bio,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Bio (optional)'),
              ),
              DropdownButtonFormField<MedicalSpecialty>(
                initialValue: specialty,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Specialty'),
                items: MedicalSpecialty.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.labelEn)),
                    )
                    .toList(),
                onChanged: busy ? null : (s) => setState(() => specialty = s!),
              ),
              TextField(
                key: const ValueKey('profile-fee'),
                controller: fee,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Consultation fee (USD)',
                ),
              ),
              TextField(
                controller: experience,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Experience (years)',
                ),
              ),
              SwitchListTile(
                key: const ValueKey('profile-booking'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Accept new bookings'),
                value: available,
                onChanged: busy ? null : (v) => setState(() => available = v),
              ),
              const Text(
                'Working periods use local HH:mm times on the same day. Existing future reservations must fit the edited periods. Existing fees and records remain unchanged.',
              ),
              ...periods.map(
                (period) => Card(
                  key: period.key,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        DropdownButtonFormField<DayOfWeek>(
                          initialValue: period.day,
                          isExpanded: true,
                          items: DayOfWeek.values
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d.labelEn),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (d) => setState(() => period.day = d!),
                        ),
                        TextField(
                          controller: period.start,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Start (HH:mm)',
                          ),
                        ),
                        TextField(
                          controller: period.end,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'End (HH:mm)',
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('Period active'),
                          value: period.active,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => period.active = v),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  periods.remove(period);
                                  retiredPeriods.add(period);
                                }),
                          child: const Text('Remove period'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OutlinedButton(
                key: const ValueKey('profile-add-period'),
                onPressed: busy
                    ? null
                    : () => setState(
                        () => periods.add(
                          _Period(
                            const AvailabilitySlot(
                              day: DayOfWeek.monday,
                              startTime: '09:00',
                              endTime: '17:00',
                            ),
                          ),
                        ),
                      ),
                child: const Text('Add working period'),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('profile-save'),
          onPressed: busy ? null : save,
          child: const Text('Save profile'),
        ),
      ],
    );
  }
}
