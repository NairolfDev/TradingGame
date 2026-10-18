import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Apple's iOS minimum is 11 pt; this project keeps a 12 floor (see
/// docs/ui-review-2026-10-18 in the plan). Smaller text is hard to read on phones.
void main() {
  test('no UI text below 12', () {
    final pattern = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
    final offenders = <String>[];
    for (final file in Directory('lib/ui').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          if (double.parse(m.group(1)!) < 12) {
            offenders.add('${file.path}:${i + 1} fontSize ${m.group(1)}');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
