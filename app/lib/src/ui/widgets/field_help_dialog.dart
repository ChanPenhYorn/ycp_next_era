import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

/// "Where do I find this?" — shown from the `?` beside a buyer field.
///
/// The reference stores put a screenshot behind every field, and the reason is
/// sound: an id typed wrong is a top-up delivered to a stranger, and the buyer
/// finds out afterwards. What this app will not do is ship a screenshot of a
/// game it does not run, so the wording does the work and a screenshot from the
/// catalogue is rendered only when one is actually there.
Future<void> showFieldHelp(BuildContext context, RequiredField field) {
  return showDialog<void>(
    context: context,
    builder: (_) => FieldHelpDialog(field: field),
  );
}

/// Resolves the instructions for a field, in order of who knows best:
/// the catalogue's own `help_*`, then the copy for a field key we recognise,
/// then a general answer. Never an empty dialog.
String fieldHelpBody(AppL10n l10n, RequiredField field, String locale) {
  final fromCatalogue = field.help(locale);
  if (fromCatalogue != null) return fromCatalogue;

  // Keyed on the field name, because that is what the supplier adapter and the
  // seeds agree on: Bay2Game's `userid` and `serverid`. A key we do not know
  // gets the general answer instead of a guess about the wrong game.
  return switch (field.key) {
    'userid' || 'game_user_id' || 'player_id' => l10n.fieldHelpUserid,
    'serverid' || 'game_zone_id' || 'zone_id' || 'server' => l10n.fieldHelpZone,
    _ => l10n.fieldHelpGeneric,
  };
}

class FieldHelpDialog extends StatelessWidget {
  const FieldHelpDialog({required this.field, super.key});

  final RequiredField field;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final image = field.guideImageUrl;

    return AlertDialog(
      title: Text(
        '${l10n.fieldHelpTitle} · ${field.label(locale)}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null && image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.contain,
                  // A missing screenshot must not leave a broken box in a
                  // dialog about where to find a number.
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              fieldHelpBody(l10n, field, locale),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            if (field.placeholder != null && field.placeholder!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                l10n.fieldHelpExample,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink400,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                field.placeholder!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 15, color: AppColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.fieldHelpWarning,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.ink400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
