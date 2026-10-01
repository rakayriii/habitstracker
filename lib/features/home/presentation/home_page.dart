import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/metric_block.dart';
import '../../../core/widgets/section_header.dart';
import '../../focus/presentation/focus_list.dart';
import '../../goals/presentation/goal_card.dart';
import '../../../domain/models/finance_summary.dart';
import '../../goals/providers/goal_providers.dart';
import '../../projects/presentation/project_card.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/home_providers.dart';
import 'settings_sheet.dart';

/// Home is an aggregation layer. Every number is read from the module that owns
/// it: net worth and the trend from Finance, focus from the focus table, goals
/// from the goals table, projects from the projects table. Nothing is copied
/// here, which is why a transaction added in Finance moves this screen.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final summary = ref.watch(financeSummaryProvider);
    final focus = ref.watch(focusCountsProvider);
    final overdue = ref.watch(overdueFocusProvider).value;
    final next = ref.watch(nextFocusProvider);
    final goals = ref.watch(homeGoalsProvider);
    final projects = ref.watch(homeProjectsProvider);
    final openTasks = ref.watch(openTaskCountProvider).value ?? 0;
    final name = ref.watch(operatorNameProvider);
    final initial = ref.watch(operatorInitialProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MyOSSpace.xl),
        children: [
          AppPageHeader(
            workspace: 'Home',
            title: '${Fmt.greeting(now)}, $name',
            counter: '${focus.done}/${focus.total} fokus',
            avatarInitial: initial,
            onAvatarTap: () => showSettingsSheet(context, ref),
            meta: '${Fmt.longDate(now)} · ${Fmt.clock(now)} WIB'
                '${overdue != null && overdue.isNotEmpty ? ' · ${overdue.length} lewat' : ''}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AsyncContent<FinanceSummary>(
                  value: summary,
                  onRetry: () => ref.invalidate(financeSummaryProvider),
                  builder: (data) => _NetWorthPanel(
                    netWorth: data.netWorth,
                    delta: data.netWorthDeltaRatio,
                    deltaAmount: data.netWorthDelta,
                    trend: data.trend,
                    retained: data.retained,
                    retentionRate: data.retentionRate,
                    liquid: data.liquidValue,
                  ),
                ),
                const SizedBox(height: MyOSSpace.sm),
                const _FinanceLink(),
                const SizedBox(height: MyOSSpace.md),

                SectionHeader(
                  title: "Today's focus",
                  count: '${focus.done}/${focus.total}',
                  actionLabel: '+ Tambah',
                  onAction: () => context.push('/focus/new'),
                ),
                const SizedBox(height: 4),
                if (next != null)
                  Text(
                    'Berikutnya ${next.priority.label} · ${next.title}',
                    style: MyOSText.bodySm.copyWith(
                      fontSize: 11,
                      color: MyOSColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: MyOSSpace.sm),
                const FocusList(),

                const SizedBox(height: MyOSSpace.lg),
                SectionHeader(
                  title: 'Active goals',
                  count: '${goals.value?.length ?? 0}',
                  actionLabel: 'Semua',
                  onAction: () => context.go('/goals'),
                ),
                const SizedBox(height: MyOSSpace.sm),
                AsyncContent(
                  value: goals,
                  onRetry: () => ref.invalidate(goalsProvider),
                  builder: (rows) {
                    if (rows.isEmpty) {
                      return AppCard(
                        onTap: () => context.go('/goals'),
                        child: Text(
                          'Belum ada target aktif. Buat target pertama di '
                          'layar Goals.',
                          style: MyOSText.bodySm.copyWith(height: 18 / 12),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final goal in rows) ...[
                          GoalCompactRow(goal: goal),
                          const SizedBox(height: MyOSSpace.sm),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: MyOSSpace.sm),
                SectionHeader(
                  title: 'Active projects',
                  count: '$openTasks task terbuka',
                  actionLabel: 'Semua',
                  onAction: () => context.go('/projects'),
                ),
                const SizedBox(height: MyOSSpace.sm),
                AsyncContent(
                  value: projects,
                  onRetry: () => ref.invalidate(projectsProvider),
                  builder: (rows) {
                    if (rows.isEmpty) {
                      return AppCard(
                        onTap: () => context.go('/projects'),
                        child: Text(
                          'Tidak ada proyek yang sedang jalan. Buka Projects '
                          'untuk melihat yang sudah selesai.',
                          style: MyOSText.bodySm.copyWith(height: 18 / 12),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final project in rows) ...[
                          ProjectCompactRow(project: project, now: now),
                          const SizedBox(height: MyOSSpace.sm),
                        ],
                      ],
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

class _NetWorthPanel extends StatelessWidget {
  const _NetWorthPanel({
    required this.netWorth,
    required this.delta,
    required this.deltaAmount,
    required this.trend,
    required this.retained,
    required this.retentionRate,
    required this.liquid,
  });

  final int netWorth;

  /// Null when the 30 day baseline is not positive, in which case the card
  /// shows the absolute change only.
  final double? delta;
  final int deltaAmount;
  final List<double> trend;
  final int retained;
  final double retentionRate;
  final int liquid;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetricBlock(
            label: 'Net worth',
            value: Fmt.idr(netWorth),
            delta: delta == null ? null : Fmt.signedPercent(delta!),
            deltaPositive: (delta ?? 0) >= 0,
          ),
          const SizedBox(height: 2),
          Text(
            '30 hari · ${Fmt.signedIdr(deltaAmount)}',
            style: MyOSText.dataSm.copyWith(fontSize: 10),
          ),
          if (trend.length > 1) ...[
            const SizedBox(height: MyOSSpace.sm),
            Sparkline(points: trend),
          ],
          const SizedBox(height: MyOSSpace.md),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Liquid',
                  value: Fmt.idrCompact(liquid),
                ),
              ),
              const SizedBox(width: MyOSSpace.sm),
              Expanded(
                child: _MiniStat(
                  label: 'Retained ${Fmt.percent(retentionRate)}',
                  value: Fmt.idrCompact(retained),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppWell(
      padding: const EdgeInsets.symmetric(
        horizontal: MyOSSpace.sm,
        vertical: 6,
      ),
      child: Column(
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
            style: MyOSText.dataMd.copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FinanceLink extends StatelessWidget {
  const _FinanceLink();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/finance'),
        borderRadius: BorderRadius.circular(MyOSRadius.lg),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: MyOSSpace.xs),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Buka ringkasan keuangan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MyOSFonts.data,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: MyOSColors.accentDim,
                  ),
                ),
              ),
              SizedBox(width: MyOSSpace.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: MyOSColors.accentDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
