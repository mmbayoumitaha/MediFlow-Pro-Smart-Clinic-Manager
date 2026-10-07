import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow/features/clinic/data/demo_fixtures.dart';
import 'package:mediflow/features/clinic/domain/app_enums.dart';
import 'package:mediflow/routes/route_access.dart';

const portalPaths = {
  UserRole.patient: [
    '/patient',
    '/patient/book',
    '/patient/prescriptions',
    '/patient/doctors',
    '/patient/appointments',
    '/patient/profile',
  ],
  UserRole.doctor: [
    '/doctor',
    '/doctor/schedule',
    '/doctor/patients',
    '/doctor/profile',
  ],
  UserRole.admin: [
    '/admin',
    '/admin/appointments',
    '/admin/doctors',
    '/admin/patients',
    '/admin/billing',
  ],
};

void main() {
  final user = DemoFixtures.generatePatients().first;
  for (final role in UserRole.values) {
    test('${role.value} route policy covers every portal and public path', () {
      final account = user.copyWith(role: role);
      for (final entry in portalPaths.entries) {
        for (final path in entry.value) {
          expect(
            RouteAccess.redirect(path, account),
            entry.key == role ? null : RouteAccess.home(role),
            reason: path,
          );
        }
      }
      for (final path in RouteAccess.publicPaths) {
        expect(RouteAccess.redirect(path, account), RouteAccess.home(role));
      }
      for (final path in [
        '/administrator',
        '/patientish',
        '/doctor-archive',
        '/unknown',
      ]) {
        expect(RouteAccess.redirect(path, account), RouteAccess.home(role));
      }
    });
  }
  test('anonymous and inactive accounts cannot enter any portal', () {
    for (final account in [null, user.copyWith(isActive: false)]) {
      for (final paths in portalPaths.values) {
        for (final path in paths) {
          expect(RouteAccess.redirect(path, account), '/login');
        }
      }
      for (final path in RouteAccess.publicPaths) {
        expect(RouteAccess.redirect(path, account), isNull);
      }
    }
  });
}
