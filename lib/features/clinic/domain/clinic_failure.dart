enum FailureCode { invalidInput, unauthorized, notFound, conflict, unavailable }

class ClinicFailure implements Exception {
  final FailureCode code;
  final String message;

  const ClinicFailure(this.code, this.message);

  @override
  String toString() => message;
}
