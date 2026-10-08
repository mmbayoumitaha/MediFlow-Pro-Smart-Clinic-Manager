import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_failure.dart';
import '../domain/app_enums.dart';
import '../domain/clinic_snapshot.dart';
import '../domain/entities.dart';
import 'firebase_clinic_mapper.dart';

abstract interface class ClinicRecords {
  Future<ClinicSnapshot> read(ClinicUser user);
  Stream<ClinicSnapshot> watch(ClinicUser user);
}

class _Row {
  final String id;
  final Map<String, dynamic> data;
  const _Row(this.id, this.data);
}

class _Part {
  final String name;
  final Future<List<_Row>> Function() read;
  final Stream<List<_Row>> Function() watch;
  const _Part(this.name, this.read, this.watch);
}

class FirebaseClinicRecords implements ClinicRecords {
  final FirebaseFirestore firestore;
  final FirebaseClinicMapper mapper;
  const FirebaseClinicRecords(this.firestore, this.mapper);

  _Part _query(String name, Query<Map<String, dynamic>> query) {
    List<_Row> rows(QuerySnapshot<Map<String, dynamic>> value) =>
        value.docs.map((doc) => _Row(doc.id, doc.data())).toList();
    return _Part(
      name,
      () async =>
          rows(await query.get(const GetOptions(source: Source.server))),
      () => query
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => !snapshot.metadata.isFromCache)
          .map(rows),
    );
  }

  _Part _ownPatient(ClinicUser user) {
    final ref = firestore.collection('users').doc(user.id);
    List<_Row> rows(DocumentSnapshot<Map<String, dynamic>> doc) =>
        doc.exists ? [_Row(doc.id, doc.data()!)] : [];
    return _Part(
      'patients',
      () async => rows(await ref.get(const GetOptions(source: Source.server))),
      () => ref
          .snapshots(includeMetadataChanges: true)
          .where((doc) => !doc.metadata.isFromCache)
          .map(rows),
    );
  }

  List<_Part> _parts(ClinicUser user) {
    if (user.role == UserRole.admin) {
      return [
        _query(
          'patients',
          firestore.collection('users').where('role', isEqualTo: 'patient'),
        ),
        for (final name in [
          'doctors',
          'appointments',
          'prescriptions',
          'invoices',
        ])
          _query(name, firestore.collection(name)),
      ];
    }
    if (user.role == UserRole.patient) {
      return [
        _ownPatient(user),
        _query('doctors', firestore.collection('doctors')),
        for (final name in ['appointments', 'prescriptions', 'invoices'])
          _query(
            name,
            firestore.collection(name).where('patientId', isEqualTo: user.id),
          ),
      ];
    }
    return [
      _query(
        'doctors',
        firestore.collection('doctors').where('userId', isEqualTo: user.id),
      ),
      _query(
        'patients',
        firestore
            .collection('doctorPatients')
            .doc(user.id)
            .collection('patients'),
      ),
      for (final name in ['appointments', 'prescriptions'])
        _query(
          name,
          firestore.collection(name).where('doctorUserId', isEqualTo: user.id),
        ),
    ];
  }

  ClinicSnapshot _snapshot(Map<String, List<_Row>> values) => ClinicSnapshot(
    doctors: (values['doctors'] ?? [])
        .map((row) => mapper.doctor(row.id, row.data))
        .toList(),
    patients: (values['patients'] ?? [])
        .map((row) => mapper.user(row.id, row.data))
        .toList(),
    appointments: (values['appointments'] ?? [])
        .map((row) => mapper.appointment(row.id, row.data))
        .toList(),
    prescriptions: (values['prescriptions'] ?? [])
        .map((row) => mapper.prescription(row.id, row.data))
        .toList(),
    invoices: (values['invoices'] ?? [])
        .map((row) => mapper.invoice(row.id, row.data))
        .toList(),
  );

  @override
  Future<ClinicSnapshot> read(ClinicUser user) async {
    try {
      final parts = _parts(user);
      final values = await Future.wait(parts.map((part) => part.read()));
      return _snapshot({
        for (var index = 0; index < parts.length; index++)
          parts[index].name: values[index],
      });
    } catch (error) {
      throw firebaseFailure(error);
    }
  }

  @override
  Stream<ClinicSnapshot> watch(ClinicUser user) => Stream.multi((controller) {
    final parts = _parts(user), values = <String, List<_Row>>{};
    final subscriptions = <StreamSubscription<List<_Row>>>[];
    bool failed = false;
    for (final part in parts) {
      subscriptions.add(
        part.watch().listen(
          (rows) {
            if (failed) return;
            try {
              values[part.name] = rows;
              if (values.length == parts.length) {
                controller.add(_snapshot(values));
              }
            } catch (error, stack) {
              failed = true;
              values.clear();
              controller.addError(firebaseFailure(error), stack);
            }
          },
          onError: (Object error, StackTrace stack) {
            failed = true;
            values.clear();
            controller.addError(firebaseFailure(error), stack);
          },
        ),
      );
    }
    controller.onCancel = () async {
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    };
  });
}
