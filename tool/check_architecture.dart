import 'dart:io';

/// Enforce the framework-independent domain boundary without adding packages.
void main() {
  final violations = <String>[];
  var checked = 0;
  final directives = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
  for (final feature in ['auth', 'clinic']) {
    final directory = Directory('lib/features/$feature/domain');
    if (!directory.existsSync()) {
      violations.add('Missing domain directory: ${directory.path}');
      continue;
    }
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      checked++;
      for (final directive in directives.allMatches(file.readAsStringSync())) {
        final imported = directive.group(1)!;
        if (imported.startsWith('dart:') && imported != 'dart:ui') continue;
        Uri target;
        if (imported.startsWith('package:mediflow/')) {
          target = Directory.current.uri.resolve(
            'lib/${imported.substring('package:mediflow/'.length)}',
          );
        } else if (imported.startsWith('package:') || imported.contains(':')) {
          violations.add('${file.path} depends on $imported');
          continue;
        } else {
          target = file.absolute.uri.resolve(imported);
        }
        if (!target.path.contains('/features/auth/domain/') &&
            !target.path.contains('/features/clinic/domain/')) {
          violations.add('${file.path} crosses the domain boundary: $imported');
        }
      }
    }
  }
  if (violations.isNotEmpty) {
    stderr.writeln(violations.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln(
      'Verified $checked domain files: no framework, data or presentation dependencies.',
    );
  }
}
