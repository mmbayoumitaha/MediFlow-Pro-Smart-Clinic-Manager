import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/core/providers/app_dependencies.dart';
import 'package:mediflow/core/providers/app_providers.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';

void main() {
  test(
    'account switches and logout synchronously rescope every read provider',
    () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 6, 9)),
        ],
      );
      addTearDown(container.dispose);
      // Establish the stream before login; anonymous reads remain empty.
      expect(container.read(appointmentsProvider), isEmpty);
      await container.read(clinicViewModelProvider.notifier).refresh();
      final auth = container.read(authProvider.notifier);
      await auth.login('mariam@email.com', 'password123', UserRole.admin);
      expect(container.read(authProvider).currentUser!.role, UserRole.patient);
      expect(container.read(appointmentsProvider).map((a) => a.id), [
        'apt-001',
        'apt-004',
      ]);
      expect(container.read(invoicesProvider).map((i) => i.id), ['inv-001']);
      container.read(searchQueryProvider.notifier).state = 'Ahmed';
      container.read(selectedSpecialtyProvider.notifier).state =
          MedicalSpecialty.cardiology;
      await auth.logout();
      expect(container.read(appointmentsProvider), isEmpty);
      expect(container.read(patientsProvider), isEmpty);
      expect(container.read(invoicesProvider), isEmpty);
      expect(container.read(doctorsProvider), isEmpty);
      expect(container.read(searchQueryProvider), '');
      expect(container.read(selectedSpecialtyProvider), isNull);
      await auth.login('layla@email.com', 'password123', UserRole.admin);
      expect(container.read(appointmentsProvider).map((a) => a.id), [
        'apt-003',
        'apt-008',
      ]);
      expect(container.read(prescriptionsProvider).map((p) => p.id), [
        'presc-001',
      ]);
      expect(container.read(invoicesProvider), isEmpty);
      await auth.logout();
      await auth.login('sara@mediflow.com', 'password123', UserRole.patient);
      expect(container.read(doctorsProvider).single.id, 'doc-002');
      expect(container.read(appointmentsProvider).map((a) => a.id), [
        'apt-004',
        'apt-008',
      ]);
      expect(container.read(patientsProvider).map((p) => p.id), [
        'pat-001',
        'pat-003',
      ]);
      expect(container.read(invoicesProvider), isEmpty);
      await auth.logout();
      await auth.login('demo@mediflow.com', 'password123', UserRole.admin);
      expect(container.read(appointmentsProvider), hasLength(8));
      expect(container.read(patientsProvider), hasLength(5));
      expect(container.read(invoicesProvider), hasLength(3));
    },
  );
}
