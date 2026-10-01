import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_detail_scaffold.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/async_view.dart';
import '../../../domain/models/transaction.dart';
import '../providers/finance_providers.dart';

/// Read only view of one ledger row, with edit and delete. Deleting asks first
/// because a transaction is the reason a balance is what it is.
class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionByIdProvider(transactionId));

    return AppDetailScaffold(
      title: 'Transaksi',
      actions: [
        HeaderAction(
          icon: Icons.edit_outlined,
          tooltip: 'Edit transaksi',
          onPressed: transaction.value == null
              ? null
              : () => context.push('/finance/transaction/$transactionId/edit'),
        ),
      ],
      bottomBar: TextButton(
        onPressed: transaction.value == null
            ? null
            : () => _confirmDelete(context, ref),
        child: Text(
          'Hapus transaksi',
          style: MyOSText.labelMd.copyWith(color: MyOSColors.negative),
        ),
      ),
      child: AsyncContent<Transaction?>(
        value: transaction,
        onRetry: () => ref.invalidate(transactionByIdProvider(transactionId)),
        builder: (data) {
          if (data == null) {
            return NotFoundPanel(
              what: 'Transaksi ini',
              onBack: () => context.pop(),
            );
          }
          final (label, tone) = switch (data.type) {
            TransactionType.income => (
              Fmt.signedIdr(data.amount),
              BadgeTone.positive,
            ),
            TransactionType.expense => (
              '-${Fmt.idr(data.amount)}',
              BadgeTone.critical,
            ),
            TransactionType.transfer => (
              Fmt.idr(data.amount),
              BadgeTone.accent,
            ),
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data.type.label.toUpperCase(),
                          style: MyOSText.labelSm,
                        ),
                        const Spacer(),
                        AppBadge(
                          label: data.isTransfer ? 'Transfer' : data.displayCategory,
                          tone: tone,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: MyOSSpace.xs),
                    Text(
                      data.title,
                      style: MyOSText.headlineSm,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: MyOSSpace.xs),
                    Text(
                      label,
                      style: MyOSText.dataLg.copyWith(
                        color: switch (data.type) {
                          TransactionType.income => MyOSColors.positive,
                          TransactionType.expense => MyOSColors.textPrimary,
                          TransactionType.transfer => MyOSColors.accentDim,
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MyOSSpace.lg),
              _Rows(transaction: data),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hapus transaksi?',
      message:
          'Saldo akun akan dihitung ulang setelah transaksi ini dihapus. '
          'Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Hapus',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runGuarded(
      context,
      () => ref.read(financeActionsProvider).deleteTransaction(transactionId),
      successMessage: 'Transaksi dihapus',
    );
    if (ok && context.mounted) context.pop();
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Kategori', transaction.displayCategory),
      (
        transaction.isTransfer ? 'Dari akun' : 'Akun',
        transaction.accountName,
      ),
      if (transaction.isTransfer)
        ('Ke akun', transaction.targetAccountName ?? 'Tidak diketahui'),
      ('Tanggal', Fmt.longDate(transaction.date)),
      ('Dicatat', Fmt.shortDate(transaction.createdAt)),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.md),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _Row(
              label: rows[i].$1,
              value: rows[i].$2,
              divider: i < rows.length - 1,
            ),
          if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MyOSSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CATATAN', style: MyOSText.labelSm),
                  const SizedBox(height: 4),
                  Text(
                    transaction.notes!,
                    style: MyOSText.bodySm.copyWith(height: 18 / 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.divider,
  });

  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: MyOSSpace.sm),
      decoration: divider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: MyOSColors.hairline)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: MyOSText.bodySm.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: MyOSSpace.md),
          Flexible(
            child: Text(
              value,
              style: MyOSText.dataMd.copyWith(fontSize: 13),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
