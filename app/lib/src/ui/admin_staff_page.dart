import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/order_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/async_value_view.dart';

/// Who can run the staff screens, and who can manage roles.
///
/// Admins only. The database checks it again on every change: `admin_set_role`
/// refuses a self-change, so there is always at least one admin left.
class AdminStaffPage extends ConsumerStatefulWidget {
  const AdminStaffPage({super.key});

  @override
  ConsumerState<AdminStaffPage> createState() => _AdminStaffPageState();
}

class _AdminStaffPageState extends ConsumerState<AdminStaffPage> {
  final _email = TextEditingController();
  StaffMember? _found;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(adminStaffProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final staff = ref.watch(adminStaffProvider);

    return AdminGate(
      adminOnly: true,
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminHeader(
              title: l10n.adminStaffTitle,
              subtitle: l10n.adminStaffNote,
              onBack: () => context.go('/admin'),
              action: IconButton(
                tooltip: l10n.retry,
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _refresh,
              ),
            ),
            const SizedBox(height: 14),
            AdminSection(
              title: l10n.adminFindByEmail,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: l10n.adminEmailLabel,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _find(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy ? null : _find,
                        child: Text(l10n.adminFindButton),
                      ),
                    ],
                  ),
                  if (_found != null) ...[
                    const SizedBox(height: 12),
                    _RoleCard(member: _found!, busy: _busy, onChange: _setRole),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            AsyncValueView(
              value: staff,
              onRetry: _refresh,
              builder: (members) => members.isEmpty
                  ? AdminEmpty(l10n.adminStaffEmpty)
                  : Column(
                      children: [
                        for (final member in members)
                          _RoleCard(
                            member: member,
                            busy: _busy,
                            onChange: _setRole,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _find() async {
    final l10n = AppL10n.of(context);
    final email = _email.text.trim();
    if (email.isEmpty) return;

    setState(() => _busy = true);
    try {
      final member = await ref
          .read(adminRepositoryProvider)
          .findUserByEmail(email);
      if (!mounted) return;
      setState(() {
        _found = member;
        _busy = false;
      });
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() {
        _found = null;
        _busy = false;
      });
      _toast(_message(l10n, error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  Future<void> _setRole(StaffMember member, String role) async {
    final l10n = AppL10n.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setRole(userId: member.id, role: role);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (_found?.id == member.id) {
          _found = StaffMember(
            id: member.id,
            displayName: member.displayName,
            role: role,
          );
        }
      });
      _toast(l10n.adminRoleSaved);
      _refresh();
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_message(l10n, error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  String _message(AppL10n l10n, String code) => switch (code) {
    'user_not_found' => l10n.adminUserNotFound,
    'cannot_change_own_role' => l10n.adminCannotChangeOwn,
    'not_authorized' => l10n.adminOnly,
    _ => l10n.somethingWentWrong,
  };

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.member,
    required this.busy,
    required this.onChange,
  });

  final StaffMember member;
  final bool busy;
  final void Function(StaffMember member, String role) onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final roles = <String, String>{
      'customer': l10n.adminRoleCustomer,
      'staff': l10n.adminRoleStaff,
      'admin': l10n.adminRoleAdmin,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.ink800),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.displayName.isEmpty ? member.id : member.displayName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in roles.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: member.role == entry.key,
                  onSelected: busy || member.role == entry.key
                      ? null
                      : (_) => onChange(member, entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
