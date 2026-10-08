import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_failure.dart';

abstract interface class ClinicCommands {
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data, {
    required String expectedUid,
  });
}

class FirebaseClinicCommands implements ClinicCommands {
  final FirebaseFunctions functions;
  const FirebaseClinicCommands(this.functions);
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data, {
    required String expectedUid,
  }) async {
    try {
      final result = await functions.httpsCallable(name).call<dynamic>({
        ...data,
        'expectedActorUid': expectedUid,
      });
      if (result.data == null) return {};
      return Map<String, dynamic>.from(result.data as Map);
    } catch (error) {
      throw firebaseFailure(error);
    }
  }
}
