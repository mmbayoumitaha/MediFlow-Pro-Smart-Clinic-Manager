/// A scoped backend may emit a cleared snapshot while waiting for the new
/// identity's server reads. Presentation must show loading, not an empty clinic.
abstract interface class ClinicReadiness {
  bool get isReady;
}
