import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../features/orders/domain/order_exception.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/async_value_view.dart';
import 'widgets/confirm_action.dart';

/// Buyer tickets.
///
/// Status and priority are the database's words, shown in the reader's
/// language, because a person picks them from buttons rather than reading them
/// off a bank statement.
class AdminSupportPage extends ConsumerStatefulWidget {
  const AdminSupportPage({this.initialStatus, super.key});

  final String? initialStatus;

  @override
  ConsumerState<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends ConsumerState<AdminSupportPage> {
  late String? _status = widget.initialStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tickets = ref.watch(adminTicketsProvider(_status));

    void refresh() {
      ref.invalidate(adminTicketsProvider);
      ref.invalidate(adminOverviewProvider);
    }

    return AdminGate(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminHeader(
            title: l10n.adminSupportTitle,
            onBack: () => context.go('/admin'),
            action: IconButton(
              tooltip: l10n.retry,
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: refresh,
            ),
          ),
          const SizedBox(height: 12),
          AdminChipRow(
            selected: _status,
            onSelected: (value) => setState(() => _status = value),
            options: [
              AdminChipOption(null, l10n.adminFilterAll),
              AdminChipOption('open', l10n.adminTicketOpen),
              AdminChipOption('in_progress', l10n.adminTicketInProgress),
              AdminChipOption('resolved', l10n.adminTicketResolved),
              AdminChipOption('closed', l10n.adminTicketClosed),
            ],
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: tickets,
            onRetry: refresh,
            builder: (rows) => rows.isEmpty
                ? AdminEmpty(l10n.adminTicketsEmpty)
                : Column(
                    children: [
                      for (final ticket in rows)
                        _TicketCard(ticket: ticket, onDone: refresh),
                    ],
                  ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  const _TicketCard({required this.ticket, required this.onDone});

  final SupportTicket ticket;
  final VoidCallback onDone;

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ticket = widget.ticket;
    final note = _note.text.trim();

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
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              _Tag(
                _statusLabel(ticket.status, l10n),
                _statusTone(ticket.status),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                adminStamp(ticket.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.ink400),
              ),
              if (ticket.contact != null && ticket.contact!.isNotEmpty)
                SelectableText(
                  ticket.contact!,
                  style: const TextStyle(fontSize: 11, color: AppColors.ink400),
                ),
            ],
          ),
          if (ticket.body != null && ticket.body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              ticket.body!,
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ],
          if (ticket.adminNote != null && ticket.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.adminTicketNote}: ${ticket.adminNote}',
              style: const TextStyle(fontSize: 11, color: AppColors.ink400),
            ),
          ],
          const SizedBox(height: 10),
          // Priority is a staff decision, not the buyer's: they set it, the
          // ticket does not.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in const ['low', 'normal', 'high'])
                ChoiceChip(
                  label: Text(
                    _priorityLabel(value, l10n),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: ticket.priority == value,
                  onSelected: _busy ? null : (_) => _set(priority: value),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            minLines: 1,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.adminTicketNote,
              helperText: ticket.adminNote,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ticket.status == 'open')
                OutlinedButton(
                  onPressed: _busy ? null : () => _set(status: 'in_progress'),
                  child: Text(l10n.adminTicketStart),
                ),
              if (ticket.isOpen)
                FilledButton(
                  onPressed: _busy ? null : () => _set(status: 'resolved'),
                  child: Text(l10n.adminTicketResolve),
                ),
              if (ticket.status != 'closed')
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: _busy ? null : () => _set(status: 'closed'),
                  child: Text(l10n.adminTicketClose),
                ),
              // A note on its own, without touching the status.
              TextButton(
                onPressed: _busy || note.isEmpty ? null : () => _set(),
                child: Text(l10n.adminTicketNote),
              ),
              if (ticket.orderId != null)
                TextButton(
                  onPressed: () =>
                      context.go('/admin/orders/${ticket.orderId}'),
                  child: Text(l10n.adminTicketOpenOrder),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _set({String? status, String? priority}) async {
    final l10n = AppL10n.of(context);
    final note = _note.text.trim();

    // Closing used to apply on one tap from a low-emphasis text button, and
    // nothing on this screen brings a closed ticket back.
    if (status == 'closed') {
      final confirmed = await confirmAction(
        context,
        title: l10n.adminTicketCloseTitle,
        confirmLabel: l10n.adminTicketClose,
        message: l10n.adminTicketCloseBody,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setSupportStatus(
            ticketId: widget.ticket.id,
            status: status,
            priority: priority,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) return;
      _note.clear();
      setState(() => _busy = false);
      widget.onDone();
    } on OrderException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(
        error.code == 'not_authorized'
            ? l10n.adminOnly
            : l10n.somethingWentWrong,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(l10n.somethingWentWrong);
    }
  }

  String _statusLabel(String status, AppL10n l10n) => switch (status) {
    'open' => l10n.adminTicketOpen,
    'in_progress' => l10n.adminTicketInProgress,
    'resolved' => l10n.adminTicketResolved,
    'closed' => l10n.adminTicketClosed,
    _ => status,
  };

  Color _statusTone(String status) => switch (status) {
    'open' => AppColors.warn,
    'in_progress' => AppColors.brand,
    'resolved' => AppColors.accent,
    _ => AppColors.ink400,
  };

  String _priorityLabel(String value, AppL10n l10n) => switch (value) {
    'low' => l10n.adminPriorityLow,
    'high' => l10n.adminPriorityHigh,
    _ => l10n.adminPriorityNormal,
  };

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10.5, color: color)),
  );
}
