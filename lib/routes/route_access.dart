import '../features/clinic/domain/app_enums.dart';
import '../features/clinic/domain/entities.dart';

/// Matches whole path segments; a selected demo role never grants access.
abstract final class RouteAccess {
  static const publicPaths = {'/', '/onboarding', '/login', '/register'};

  static String home(UserRole role) => '/${role.value}';

  static String? redirect(String path, ClinicUser? user) {
    final authenticated = user?.isActive == true;
    if (!authenticated) return publicPaths.contains(path) ? null : '/login';
    final root = home(user!.role);
    if (path == root || path.startsWith('$root/')) return null;
    return root;
  }
}
