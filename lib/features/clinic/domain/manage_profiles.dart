import 'clinic_repository.dart';
import 'entities.dart';
import 'profile_policy.dart';

class ManageProfiles {
  final ClinicRepository _repository;
  final String Function() _newId;
  const ManageProfiles(this._repository, this._newId);
  Future<ClinicUser> patient(
    ClinicUser? actor,
    ClinicUser expected,
    ContactInput input,
  ) {
    ProfilePolicy.active(actor);
    return _repository.savePatient(
      actor: actor!,
      expected: expected,
      input: input,
    );
  }

  Future<Doctor> doctor(
    ClinicUser? actor,
    Doctor? expected,
    DoctorInput input,
  ) {
    ProfilePolicy.active(actor);
    if (expected == null) ProfilePolicy.admin(actor);
    return _repository.saveDoctor(
      actor: actor!,
      expected: expected,
      input: input,
      newDoctorId: expected == null ? _newId() : null,
      newUserId: expected == null ? _newId() : null,
    );
  }

  Future<void> removePatient(ClinicUser? actor, ClinicUser expected) {
    ProfilePolicy.admin(actor);
    return _repository.removePatient(actor: actor!, expected: expected);
  }

  Future<void> removeDoctor(ClinicUser? actor, Doctor expected) {
    ProfilePolicy.admin(actor);
    return _repository.removeDoctor(actor: actor!, expected: expected);
  }
}
