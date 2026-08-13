import 'package:diacritic/diacritic.dart';

String normalizeForCompare(String input) {
  // Mirror backend: lowercase, remove diacritics, keep only a-z.
  final lowered = input.trim().toLowerCase();
  final noMarks = removeDiacritics(lowered);
  return noMarks.replaceAll(RegExp(r'[^a-z]'), '');
}
