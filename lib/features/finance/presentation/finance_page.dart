import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/ledger_row.dart';
import '../../../core/widgets/metric_block.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/finance_summary.dart';
import '../../../domain/models/transaction.dart';
import '../providers/finance_providers.dart';

/// Finance. Every figure on this screen is computed by
/// [FinanceSummary] from the ledger, for the period selected in the rail.
/// Nothing here is a literal.
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final summary = ref.watch(financeSummaryProvider);
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final allTransactions = ref.watch(transactionsProvider);
    final counts = ref.watch(transactionTypeCountsProvider).value;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MyOSSpace.xl),
        children: [
          AppPageHeader(
            workspace: 'Finance',
            title: 'Posisi keuangan',
            counter: accounts.value == null
                ? null
                : '${accounts.value!.where((a) => a.isAsset).length} aset',
            meta: 'Periode ${period.label.toLowerCase()}',
          ),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.margin),
              itemCount: FinancePeriod.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: MyOSSpace.sm),
              itemBuilder: (context, index) {
                final option = FinancePeriod.values[index];
                return FilterChipButton(
                  label: option.label,
                  selected: option == period,
                  onSelected: () => ref
                      .read(financePeriodProvider.notifier)
                      .select(option),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MyOSSpace.margin,
              MyOSSpace.lg,
              MyOSSpace.margin,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AsyncContent<FinanceSummary>(
                  value: summary,
                  onRetry: () => ref.invalidate(financeSummaryProvider),
                  builder: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NetWorthCard(summary: data),
                      const SizedBox(height: MyOSSpace.sm),
                      Row(
                        children: [
                          Expanded(
                            child: AppWell(
                              child: _Pair(
                                label: 'Aset',
                                value: Fmt.idrCompact(data.totalAssets),
                              ),
                            ),
                          ),
                          const SizedBox(width: MyOSSpace.sm),
                          Expanded(
                            child: AppWell(
                              child: _Pair(
                                label: 'Kewajiban',
                                value: Fmt.idrCompact(data.totalLiabilities),
                                valueColor: data.totalLiabilities > 0
                                    ? MyOSColors.negative
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: MyOSSpace.lg),
                SectionHeader(
                  title: 'Alokasi aset',
                  actionLabel: 'Kelola akun',
                  onAction: () => context.push('/finance/accounts'),
                ),
                const SizedBox(height: MyOSSpace.sm),
                AsyncContent<FinanceSummary>(
                  value: summary,
                  onRetry: () => ref.invalidate(financeSummaryProvider),
                  builder: (data) {
                    if (data.allocation.isEmpty) {
                      return _EmptyAllocation(
                        onAdd: () => context.push('/finance/account/new'),
                      );
                    }
                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MyOSSpace.md,
                        vertical: MyOSSpace.md,
                      ),
                      child: Column(
                        children: [
                          AllocationBar(
                            segments: [
                              for (final slice in data.allocation) slice.weight,
                            ],
                          ),
                          const SizedBox(height: MyOSSpace.sm),
                          for (
                            var i = 0;
                            i < data.allocation.length;
                            i++
                          )
                            LedgerRow(
                              title: data.allocation[i].label,
                              // The type is only worth a second line when it
                              // says something the name does not already.
                              subtitle: _typeUnder(
                                accounts.value,
                                data.allocation[i],
                              ),
                              value:
                                  '${Fmt.idrCompact(data.allocation[i].value)}'
                                  ' · ${Fmt.percent(data.allocation[i].weight)}',
                              divider: i < data.allocation.length - 1,
                              onTap: () => context.push(
                                '/finance/account/${data.allocation[i].accountId}',
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: MyOSSpace.lg),
                SectionHeader(
                  title: 'Arus kas',
                  count: '6 bulan',
                ),
                const SizedBox(height: MyOSSpace.sm),
                AsyncContent<FinanceSummary>(
                  value: summary,
                  onRetry: () => ref.invalidate(financeSummaryProvider),
                  builder: (data) => AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Pair(
                                label: 'Masuk',
                                value: Fmt.idrCompact(data.income),
                              ),
                            ),
                            Expanded(
                              child: _Pair(
                                label: 'Keluar',
                                value: Fmt.idrCompact(data.expenses),
                              ),
                            ),
                            Expanded(
                              child: _Pair(
                                label: 'Disimpan',
                                value: Fmt.idrCompact(data.retained),
                                valueColor: data.retained >= 0
                                    ? MyOSColors.positive
                                    : MyOSColors.negative,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MyOSSpace.md),
                        CashflowBars(
                          months: [
                            for (final month in data.cashflow)
                              CashflowBar(
                                label: month.label,
                                income: month.income,
                                expenses: month.expenses,
                              ),
                          ],
                        ),
                        const SizedBox(height: MyOSSpace.sm),
                        Row(
                          children: [
                            const Flexible(child: CashflowBarsLegend()),
                            const SizedBox(width: MyOSSpace.sm),
                            Text(
                              'Retensi ${Fmt.percent(data.retentionRate)}',
                              style: MyOSText.dataSm.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: MyOSSpace.lg),
                SectionHeader(
                  title: 'Transaksi',
                  count: filter.isActive
                      ? '${transactions.value?.length ?? 0} difilter'
                      : '${allTransactions.value?.length ?? 0}',
                  actionLabel: '+ Tambah',
                  onAction: () => context.push('/finance/transaction/new'),
                ),
                const SizedBox(height: MyOSSpace.sm),
                _TransactionFilterRail(
                  counts: counts,
                  filter: filter,
                  accounts: accounts.value,
                ),
                const SizedBox(height: MyOSSpace.sm),
                AsyncContent<List<Transaction>>(
                  value: transactions,
                  onRetry: () => ref.invalidate(transactionsProvider),
                  builder: (rows) {
                    if (rows.isEmpty) {
                      return _EmptyLedger(
                        filtered: filter.isActive,
                        onClear: () => ref
                            .read(transactionFilterProvider.notifier)
                            .clear(),
                        onAdd: () => context.push('/finance/transaction/new'),
                      );
                    }
                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MyOSSpace.md,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            _TransactionRow(
                              transaction: rows[i],
                              divider: i < rows.length - 1,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricBlock(
            label: 'Net worth',
            value: Fmt.idr(summary.netWorth),
            delta: summary.netWorthDeltaRatio == null
                ? null
                : Fmt.signedPercent(summary.netWorthDeltaRatio!),
            deltaPositive: summary.netWorthDelta >= 0,
            footnote: '30 hari · ${Fmt.signedIdr(summary.netWorthDelta)}',
          ),
          if (summary.trend.length > 1) ...[
            const SizedBox(height: MyOSSpace.sm),
            Sparkline(points: summary.trend),
          ],
        ],
      ),
    );
  }
}

/// Account type as a subtitle, or an empty string when it would just repeat
/// the account name.
String _typeUnder(List<Account>? accounts, AllocationSlice slice) {
  final type = accounts
      ?.where((account) => account.id == slice.accountId)
      .firstOrNull
      ?.type
      .label;
  if (type == null || type.toLowerCase() == slice.label.toLowerCase()) return '';
  return type;
}

class _TransactionFilterRail extends ConsumerWidget {
  const _TransactionFilterRail({
    required this.counts,
    required this.filter,
    required this.accounts,
  });

  final Map<TransactionType, int>? counts;
  final TransactionFilter filter;
  final List<Account>? accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(transactionFilterProvider.notifier);
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChipButton(
            label: 'Semua',
            selected: !filter.isActive,
            onSelected: notifier.clear,
          ),
          const SizedBox(width: MyOSSpace.sm),
          for (final type in TransactionType.values) ...[
            FilterChipButton(
              label: '${type.label} ${counts?[type] ?? 0}',
              selected: filter.type == type,
              onSelected: () => notifier.setType(
                filter.type == type ? null : type,
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
          ],
          for (final account in accounts ?? const <Account>[]) ...[
            FilterChipButton(
              label: account.name,
              selected: filter.accountId == account.id,
              onSelected: () => notifier.setAccount(
                filter.accountId == account.id ? null : account.id,
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.divider});

  final Transaction transaction;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (label, color) = switch (transaction.type) {
      TransactionType.income => (
        Fmt.signedIdr(transaction.amount),
        MyOSColors.positive,
      ),
      TransactionType.expense => (
        '-${Fmt.idr(transaction.amount)}',
        MyOSColors.textPrimary,
      ),
      TransactionType.transfer => (
        Fmt.idr(transaction.amount),
        MyOSColors.accentDim,
      ),
    };

    final counterparty = transaction.isTransfer
        ? '${transaction.accountName} → ${transaction.targetAccountName ?? '?'}'
        : transaction.accountName;

    return LedgerRow(
      title: transaction.title,
      subtitle: '${Fmt.relativeDay(transaction.date, now)} · $counterparty',
      value: label,
      valueColor: color,
      divider: divider,
      onTap: () => context.push('/finance/transaction/${transaction.id}'),
    );
  }
}

class _EmptyAllocation extends StatelessWidget {
  const _EmptyAllocation({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Belum ada aset',
      message: 'Tambahkan akun atau aset untuk melihat alokasi. Saldo awal '
          ' dicatat sebagai transaksi, jadi bisa ditelusuri.',
      actionLabel: 'Tambah akun',
      onAction: onAdd,
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({
    required this.filtered,
    required this.onClear,
    required this.onAdd,
  });

  final bool filtered;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: filtered ? 'Tidak ada transaksi' : 'Belum ada transaksi',
      message: filtered
          ? 'Filter yang aktif tidak cocok dengan transaksi mana pun.'
          : 'Catat pemasukan, pengeluaran, atau transfer untuk mulai menghitung '
                'arus kas.',
      actionLabel: filtered ? 'Hapus filter' : 'Tambah transaksi',
      onAction: filtered ? onClear : onAdd,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MyOSSpace.lg),
      decoration: BoxDecoration(
        color: MyOSColors.surface,
        borderRadius: BorderRadius.circular(MyOSRadius.lg),
        border: Border.all(color: MyOSColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: MyOSText.labelSm),
          const SizedBox(height: MyOSSpace.sm),
          Text(
            message,
            style: MyOSText.bodySm.copyWith(height: 18 / 12),
          ),
          const SizedBox(height: MyOSSpace.md),
          PanelActionButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: MyOSText.labelSm.copyWith(fontSize: 9, height: 12 / 9),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: MyOSText.dataMd.copyWith(
            fontSize: 13,
            color: valueColor ?? MyOSColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
