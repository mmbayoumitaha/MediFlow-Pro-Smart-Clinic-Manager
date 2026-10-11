abstract interface class ClinicCommands {
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data, {
    required String expectedUid,
  });
}
