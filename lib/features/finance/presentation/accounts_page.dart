import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_detail_scaffold.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/ledger_row.dart';
import '../../../domain/models/account.dart';
import '../providers/finance_providers.dart';

/// Account and asset list. Balances come from the ledger cache, so the number
/// here and the number on the dashboard are the same value.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final summary = ref.watch(financeSummaryProvider);

    return AppDetailScaffold(
      title: 'Akun dan aset',
      subtitle: accounts.value == null
          ? null
          : '${accounts.value!.length} akun terdaftar',
      actions: [
        HeaderAction(
          icon: Icons.add_rounded,
          tooltip: 'Tambah akun',
          onPressed: () => context.push('/finance/account/new'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AsyncContent<List<Account>>(
            value: accounts,
            onRetry: () => ref.invalidate(accountsProvider),
            builder: (rows) {
              if (rows.isEmpty) {
                return _NoAccounts(
                  onAdd: () => context.push('/finance/account/new'),
                );
              }
              final assets = rows.where((a) => a.isAsset).toList();
              final liabilities = rows.where((a) => a.isLiability).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summary.value case final data?) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _Total(
                            label: 'Total aset',
                            value: Fmt.idr(data.totalAssets),
                          ),
                        ),
                        const SizedBox(width: MyOSSpace.sm),
                        Expanded(
                          child: _Total(
                            label: 'Kewajiban',
                            value: Fmt.idr(data.totalLiabilities),
                            valueColor: data.totalLiabilities > 0
                                ? MyOSColors.negative
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MyOSSpace.lg),
                  ],
                  Text('ASET', style: MyOSText.labelSm),
                  const SizedBox(height: MyOSSpace.sm),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MyOSSpace.md,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < assets.length; i++)
                          _AccountRow(
                            account: assets[i],
                            divider: i < assets.length - 1,
                          ),
                      ],
                    ),
                  ),
                  if (liabilities.isNotEmpty) ...[
                    const SizedBox(height: MyOSSpace.lg),
                    Text('KEWAJIBAN', style: MyOSText.labelSm),
                    const SizedBox(height: MyOSSpace.sm),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MyOSSpace.md,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < liabilities.length; i++)
                            _AccountRow(
                              account: liabilities[i],
                              divider: i < liabilities.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.divider});

  final Account account;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return LedgerRow(
      title: account.name,
      subtitle: account.isArchived
          ? '${account.type.label} · DIARSIPKAN'
          : account.type.label,
      value: Fmt.idr(account.balance),
      valueColor: account.balance < 0 ? MyOSColors.negative : null,
      divider: divider,
      onTap: () => context.push('/finance/account/${account.id}'),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppWell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: MyOSText.labelSm.copyWith(fontSize: 9, height: 12 / 9),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: MyOSText.dataMd.copyWith(fontSize: 13, color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _NoAccounts extends StatelessWidget {
  const _NoAccounts({required this.onAdd});

  final VoidCallback onAdd;

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
          Text('BELUM ADA AKUN', style: MyOSText.labelSm),
          const SizedBox(height: MyOSSpace.sm),
          Text(
            'Tambahkan rekening, e-wallet, atau aset yang Anda Pegang. Saldo '
            'awal akan tercatat sebagai transaksi pertama.',
            style: MyOSText.bodySm.copyWith(height: 18 / 12),
          ),
          const SizedBox(height: MyOSSpace.md),
          PanelActionButton(label: 'Tambah akun', onPressed: onAdd),
        ],
      ),
    );
  }
}
