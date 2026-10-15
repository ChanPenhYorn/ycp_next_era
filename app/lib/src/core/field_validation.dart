import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/models.dart';

/// What is wrong with a buyer's answer, if anything.
enum FieldProblem {
  /// Nothing was entered.
  empty,

  /// Entered, but not the shape the catalogue declares.
  format,
}

/// The catalogue's `pattern` for a field, compiled — or null when the field has
/// none.
///
/// A pattern is data: staff write it in the admin, and a supplier adapter
/// generates it. So it can be unparseable, and `RegExp` throws on a bad one.
/// That throw would take the whole product page down, so an unusable pattern is
/// treated as no pattern — the same choice `create_order` makes. Loud in a
/// debug build, silent for a buyer.
RegExp? compileFieldPattern(String? pattern) {
  if (pattern == null || pattern.trim().isEmpty) return null;

  try {
    return RegExp(pattern);
  } on FormatException catch (error) {
    if (kDebugMode) {
      debugPrint('Ignoring unusable field pattern "$pattern": $error');
    }
    return null;
  }
}

/// Longest value `create_order` will accept for a buyer field.
const int fieldValueMaxLength = 64;

/// Mirrors the gate in `create_order`: a required field must be present, match
/// the catalogue's pattern when it declares one, and stay within [fieldValueMaxLength].
///
/// The database is the authority — this exists so the buyer is told before
/// paying rather than after the supplier rejects the order.
FieldProblem? fieldProblem(RequiredField field, String raw) {
  final value = raw.trim();

  if (value.isEmpty) return FieldProblem.empty;
  if (value.length > fieldValueMaxLength) return FieldProblem.format;

  final pattern = compileFieldPattern(field.pattern);
  if (pattern != null && !pattern.hasMatch(value)) return FieldProblem.format;

  return null;
}

/// Whether the field's pattern accepts nothing but digits.
///
/// This drives the keyboard and the input formatter, so it has to be a narrow
/// check. A pattern of `^[0-9]{6,12}$` wants a number pad; `^[a-zA-Z0-9]+$`
/// holds letters, and giving it a digits-only keyboard would make a valid
/// answer impossible to type.
bool fieldWantsDigits(RequiredField field) {
  final pattern = field.pattern?.trim() ?? '';
  if (pattern.isEmpty) return false;

  final trimmed = pattern.replaceAll(RegExp(r'[\^$]'), '');
  return RegExp(r'^(\d|\[0-9\])(\{\d+(,\d*)?\}|\+|\*)?$').hasMatch(trimmed);
}

TextInputType fieldKeyboardType(RequiredField field) =>
    fieldWantsDigits(field) ? TextInputType.number : TextInputType.text;

List<TextInputFormatter> fieldInputFormatters(RequiredField field) => [
  // Applied whatever the pattern: the server caps the length too, and a
  // supplier API has no business receiving a kilobyte of junk.
  LengthLimitingTextInputFormatter(fieldValueMaxLength),
  if (fieldWantsDigits(field)) FilteringTextInputFormatter.digitsOnly,
];
