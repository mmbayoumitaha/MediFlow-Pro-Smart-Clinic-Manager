import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/firebase/firebase_failure.dart';
import '../../clinic/data/firebase_clinic_mapper.dart';
import '../../clinic/domain/entities.dart';

abstract interface class FirebaseIdentityGateway {
  String? get currentUid;
  Stream<String?> watchIdentity();
  Future<String> signIn(String email, String password);
  Future<String> createPatientIdentity(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
}

abstract interface class FirebaseProfileGateway {
  Future<ClinicUser?> read(String uid);
  Stream<ClinicUser?> watch(String uid);
}

class FirebaseSdkIdentity implements FirebaseIdentityGateway {
  final FirebaseAuth auth;
  const FirebaseSdkIdentity(this.auth);
  @override
  String? get currentUid => auth.currentUser?.uid;
  @override
  Stream<String?> watchIdentity() =>
      auth.userChanges().map((user) => user?.uid).distinct();
  @override
  Future<String> signIn(String email, String password) async {
    try {
      return (await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).user!.uid;
    } catch (error) {
      throw firebaseFailure(error);
    }
  }

  @override
  Future<String> createPatientIdentity(String email, String password) async {
    try {
      return (await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).user!.uid;
    } on FirebaseAuthException catch (error) {
      // Recover an interrupted registration only after proving the same password.
      if (error.code == 'email-already-in-use') return signIn(email, password);
      throw firebaseFailure(error);
    }
  }

  @override
  Future<void> signOut() => auth.signOut();
  @override
  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') throw firebaseFailure(error);
    }
  }
}

class FirebaseSdkProfiles implements FirebaseProfileGateway {
  final FirebaseFirestore firestore;
  final FirebaseClinicMapper mapper;
  const FirebaseSdkProfiles(this.firestore, this.mapper);
  @override
  Future<ClinicUser?> read(String uid) async {
    try {
      final doc = await firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      return doc.exists ? mapper.user(doc.id, doc.data()!) : null;
    } catch (error) {
      throw firebaseFailure(error);
    }
  }

  @override
  Stream<ClinicUser?> watch(String uid) => firestore
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where((doc) => !doc.metadata.isFromCache)
      .map((doc) => doc.exists ? mapper.user(doc.id, doc.data()!) : null);
}
