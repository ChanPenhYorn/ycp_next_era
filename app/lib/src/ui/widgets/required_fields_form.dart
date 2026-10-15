import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../core/field_validation.dart';
import '../../data/models.dart';
import 'field_help_dialog.dart';

/// The buyer-input block for a product, shared by the product page and checkout.
///
/// It is shared because the two copies had drifted: checkout painted one shared
/// error string under *every* field, so a bad game id blamed the server box too,
/// and both pages gave every field a numeric keyboard even when the pattern
/// accepted letters. One widget, one rule, one place to be wrong.
class RequiredFieldsForm extends StatelessWidget {
  const RequiredFieldsForm({
    required this.fields,
    required this.locale,
    required this.controllerFor,
    required this.errors,
    this.onChanged,
    super.key,
  });

  final List<RequiredField> fields;
  final String locale;
  final TextEditingController Function(RequiredField field) controllerFor;

  /// Per-field message, keyed by [RequiredField.key]. Only the offending field
  /// carries one.
  final Map<String, String?> errors;

  final ValueChanged<RequiredField>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields) ...[
          _FieldRow(
            field: field,
            locale: locale,
            controller: controllerFor(field),
            error: errors[field.key],
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.locale,
    required this.controller,
    required this.error,
    this.onChanged,
  });

  final RequiredField field;
  final String locale;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<RequiredField>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                field.label(locale),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              tooltip: l10n.fieldHelpTooltip,
              onPressed: () => showFieldHelp(context, field),
              icon: const Icon(Icons.help_outline),
            ),
          ],
        ),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          keyboardType: fieldKeyboardType(field),
          inputFormatters: fieldInputFormatters(field),
          textInputAction: TextInputAction.next,
          onChanged: (_) => onChanged?.call(field),
          decoration: InputDecoration(
            hintText: field.placeholder,
            errorText: error,
          ),
        ),
      ],
    );
  }
}

/// The message shown under a field, or null when there is nothing to say.
String? fieldProblemMessage(
  AppL10n l10n,
  RequiredField field,
  FieldProblem problem,
) => switch (problem) {
  FieldProblem.empty => l10n.fieldRequired,
  FieldProblem.format =>
    field.placeholder == null
        ? l10n.fieldWrongFormat
        : '${l10n.fieldWrongFormat} (${field.placeholder})',
};
