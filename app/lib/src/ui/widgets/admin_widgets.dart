import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../state/providers.dart';

/// The one place the staff role is checked before an admin screen builds.
///
/// A non-staff visitor never gets past this, so the queries behind it never
/// run: there is nothing to leak because nothing was read. It is a convenience
/// only — the database re-checks `is_staff()` in every RPC and every policy, so
/// reaching a route by hand still yields no data and no action.
class AdminGate extends ConsumerWidget {
  const AdminGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final profile = ref.watch(profileProvider);

    return profile.when(
      data: (value) =>
          (value?.isStaff ?? false) ? child : _Denied(l10n.adminOnly),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => _Denied(l10n.adminOnly),
    );
  }
}

class _Denied extends StatelessWidget {
  const _Denied(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.ink400),
      ),
    ),
  );
}

/// Title block for an admin screen, with a way back to the hub.
class AdminHeader extends StatelessWidget {
  const AdminHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (onBack != null)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            onPressed: onBack,
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 11.5, color: AppColors.ink400),
              ),
            ],
          ],
        ),
      ),
      ?action,
    ],
  );
}

/// A titled block. Every admin screen is built from these, so the spacing is
/// decided once.
class AdminSection extends StatelessWidget {
  const AdminSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.ink900,
      border: Border.all(color: AppColors.ink800),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            ?action,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// One figure. Big number, small label, and no invented comparison against a
/// period nobody stored.
class AdminStat extends StatelessWidget {
  const AdminStat({
    required this.label,
    required this.value,
    this.onTap,
    this.tone,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink850,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: tone ?? Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.ink400),
          ),
        ],
      ),
    );

    if (onTap == null) return body;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: body,
    );
  }
}

/// A tappable hub row.
class AdminTile extends StatelessWidget {
  const AdminTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.count,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Shown only when it is above zero: a badge that says "0" trains people to
  /// ignore it.
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.ink200),
    title: Text(title, style: const TextStyle(fontSize: 14)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((count ?? 0) > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warn.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.warn,
              ),
            ),
          ),
        const Icon(Icons.chevron_right, color: AppColors.ink400),
      ],
    ),
    onTap: onTap,
  );
}

class AdminChipOption {
  const AdminChipOption(this.value, this.label);

  /// The database's own value, or null for "no filter".
  final String? value;
  final String label;
}

/// Single-choice filter row. Scrolls sideways because Khmer labels are long.
class AdminChipRow extends StatelessWidget {
  const AdminChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<AdminChipOption> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(option.label, style: const TextStyle(fontSize: 11.5)),
              selected: option.value == selected,
              onSelected: (_) => onSelected(option.value),
            ),
          ),
      ],
    ),
  );
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.ink400, fontSize: 12.5),
    ),
  );
}

/// Day/month and time, in the reader's own zone. Short because it sits in
/// tables.
String adminStamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// A one-field dialog. Returns null when dismissed.
///
/// When [mandatory] is set, an empty answer is refused here as well as in the
/// database: a refund whose reason is whitespace is a refund nobody can read
/// later.
Future<String?> askAdminText(
  BuildContext context, {
  required String title,
  required String label,
  String? helper,
  String? confirmLabel,
  bool mandatory = false,
  TextInputType? keyboardType,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);

  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppL10n.of(dialogContext);
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: keyboardType,
            maxLines: keyboardType == null ? 3 : 1,
            minLines: 1,
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperMaxLines: 4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (mandatory && value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: Text(confirmLabel ?? title),
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
