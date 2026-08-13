import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:wordfriend_app/spelling/normalize.dart';

void main() {
  test('spelling normalization matches golden vectors', () async {
    // `flutter test` runs with CWD = app/.
    final file = File('../tests/spelling_golden.json');
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final cases = (decoded['cases'] as List<dynamic>?) ?? const [];

    expect(cases, isNotEmpty);

    for (final c in cases) {
      final m = c as Map<String, dynamic>;
      final input = m['input'] as String;
      final expected = m['normalized'] as String;
      final got = normalizeForCompare(input);
      expect(
        got,
        expected,
        reason: 'input=${jsonEncode(input)} expected=${jsonEncode(expected)} got=${jsonEncode(got)}',
      );
    }
  });
}
