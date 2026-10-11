import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/clinic/data/firebase_clinic_mapper.dart';
import '../../features/clinic/domain/app_enums.dart';
import '../../features/clinic/domain/billing_policy.dart';
import '../../features/clinic/domain/clinic_failure.dart';
import 'clinic_clock.dart';

class FirestoreBilling {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final ClinicClock clock;
  const FirestoreBilling(this.db, this.auth, this.clock);
  void guard(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw const ClinicFailure(
        FailureCode.unauthorized,
        'Your clinic session changed.',
      );
    }
  }

  Map<String, dynamic> requiredData(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      doc.data() ??
      (throw const ClinicFailure(
        FailureCode.notFound,
        'The billing record is unavailable.',
      ));
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> input,
    String uid,
  ) async {
    guard(uid);
    return name == 'issueAppointmentInvoice'
        ? issue(input, uid)
        : pay(input, uid);
  }

  Future<void> actor(Transaction tx, String uid) async {
    final data = requiredData(await tx.get(db.doc('users/$uid')));
    guard(uid);
    BillingPolicy.requireAdmin(FirebaseClinicMapper(clock).user(uid, data));
  }

  Future<Map<String, dynamic>> issue(
    Map<String, dynamic> input,
    String uid,
  ) async {
    final appointmentId = input['appointmentId'] as String;
    final id = await db.runTransaction<String>((tx) async {
      guard(uid);
      await actor(tx, uid);
      final visit = requiredData(
        await tx.get(db.doc('appointments/$appointmentId')),
      );
      final linkRef = db.doc('billingLinks/$appointmentId');
      final link = await tx.get(linkRef);
      guard(uid);
      if (link.exists) return link.data()!['invoiceId'] as String;
      if (visit['status'] != 'completed' ||
          visit['paymentStatus'] != 'unpaid' ||
          (visit['fee'] as num) <= 0) {
        throw const ClinicFailure(
          FailureCode.invalidInput,
          'Only a completed unpaid consultation can be invoiced.',
        );
      }
      final id = input['invoiceId'] as String;
      final ref = db.doc('invoices/$id');
      final previous = await tx.get(ref);
      guard(uid);
      if (previous.exists) {
        throw const ClinicFailure(
          FailureCode.conflict,
          'This invoice ID is already used.',
        );
      }
      BillingPolicy.cents((visit['fee'] as num).toDouble());
      tx.set(ref, {
        'id': id,
        'patientId': visit['patientId'],
        'patientName': visit['patientName'],
        'appointmentId': appointmentId,
        'items': [
          {
            'description': 'Consultation with ${visit['doctorName']}',
            'quantity': 1,
            'unitPrice': visit['fee'],
            'total': visit['fee'],
          },
        ],
        'subtotal': visit['fee'],
        'total': visit['fee'],
        'tax': 0,
        'discount': 0,
        'paymentStatus': 'unpaid',
        'paymentMethod': null,
        'issuedDate': FieldValue.serverTimestamp(),
        'paidDate': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      tx.set(linkRef, {'invoiceId': id});
      return id;
    });
    guard(uid);
    final result = requiredData(
      await db.doc('invoices/$id').get(const GetOptions(source: Source.server)),
    );
    guard(uid);
    return {...result, 'id': id};
  }

  Future<Map<String, dynamic>> pay(
    Map<String, dynamic> input,
    String uid,
  ) async {
    final id = input['invoiceId'] as String,
        ref = db.doc('invoices/${input['invoiceId']}');
    await db.runTransaction((tx) async {
      guard(uid);
      await actor(tx, uid);
      final data = requiredData(await tx.get(ref));
      final visitRef = db.doc('appointments/${data['appointmentId']}');
      final visit = requiredData(await tx.get(visitRef));
      final link = requiredData(
        await tx.get(db.doc('billingLinks/${data['appointmentId']}')),
      );
      guard(uid);
      final expected = PaymentStatus.values.firstWhere(
        (s) => s.value == input['expectedPayment'],
      );
      final target = PaymentStatus.values.firstWhere(
        (s) => s.value == input['targetPayment'],
      );
      final method = input['method'] == null
          ? null
          : DemoPaymentMethod.values.firstWhere(
              (m) => m.name == input['method'],
            );
      final invoice = FirebaseClinicMapper(clock).invoice(id, data);
      BillingPolicy.validateTransition(
        invoice,
        expected,
        target,
        method,
        clock.now(),
      );
      if (link['invoiceId'] != id ||
          visit['paymentStatus'] != expected.value ||
          visit['patientId'] != data['patientId']) {
        throw const ClinicFailure(
          FailureCode.conflict,
          'The linked billing records changed. Refresh and try again.',
        );
      }
      tx.update(ref, {
        'paymentStatus': target.value,
        if (target == PaymentStatus.paid) 'paymentMethod': method!.name,
        if (target == PaymentStatus.paid)
          'paidDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
      tx.update(visitRef, {
        'paymentStatus': target.value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });
    });
    guard(uid);
    final result = requiredData(
      await ref.get(const GetOptions(source: Source.server)),
    );
    guard(uid);
    return {...result, 'id': id};
  }
}
