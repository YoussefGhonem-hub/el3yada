import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `dioProvider`'s base URL already ends in `/api` (core/network/api_client.dart),
/// and Dio joins the base and the path as text. A path that starts with `/api/`
/// therefore asks for `/api/api/...`, which the API doesn't have. Every Phase 4–6
/// repository did that and only worked against the offline fakes.
void main() {
  test('no request path starts with /api/ (the base URL already has it)', () {
    final offenders = <String>[];
    final literal = RegExp(r'''['"]/api/''');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/gen/')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (literal.hasMatch(line)) offenders.add('$path:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'Drop the /api prefix:\n${offenders.join('\n')}');
  });
}
