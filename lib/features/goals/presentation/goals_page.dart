import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/models/goal.dart';
import '../providers/goal_providers.dart';
import 'goal_card.dart';

/// Goals. The filter is the only control and it is real: status and category
/// narrow the same list the detail screens read.
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(visibleGoalsProvider);
    final filter = ref.watch(goalFilterProvider);
    final completion = ref.watch(goalCompletionProvider).value ?? 0;
    final onTrack = ref.watch(onTrackCountProvider).value ?? 0;
    final notifier = ref.read(goalFilterProvider.notifier);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MyOSSpace.xl),
        children: [
          AppPageHeader(
            workspace: 'Goals',
            title: 'Target',
            counter: '${view.value?.statusCounts[GoalStatus.active] ?? 0} aktif',
            meta: 'Rata-rata progres ${Fmt.percent(completion)} · '
                '$onTrack on track',
          ),
          _FilterRail(
            filter: filter,
            view: view.value,
            onStatus: notifier.setStatus,
            onCategory: notifier.setCategory,
            onClear: notifier.clear,
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
                if (view.value case final data?) _SummaryStrip(data: data),
                const SizedBox(height: MyOSSpace.md),
                SectionHeader(
                  title: 'Daftar target',
                  count: '${view.value?.visible.length ?? 0}',
                  actionLabel: '+ Tambah',
                  onAction: () => context.push('/goals/new'),
                ),
                const SizedBox(height: MyOSSpace.sm),
                AsyncContent<GoalsView>(
                  value: view,
                  onRetry: () => ref.invalidate(goalsProvider),
                  builder: (data) {
                    if (data.visible.isEmpty) {
                      return _EmptyGoals(
                        filtered: filter.isActive,
                        onClear: notifier.clear,
                        onAdd: () => context.push('/goals/new'),
                      );
                    }
                    return Column(
                      children: [
                        for (final goal in data.visible) ...[
                          GoalCard(goal: goal),
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

/// One scroll rail holding both filter dimensions, separated by a hairline so
/// it is clear they are independent rather than a single list of options.
class _FilterRail extends StatelessWidget {
  const _FilterRail({
    required this.filter,
    required this.view,
    required this.onStatus,
    required this.onCategory,
    required this.onClear,
  });

  final GoalFilter filter;
  final GoalsView? view;
  final ValueChanged<GoalStatus?> onStatus;
  final ValueChanged<GoalCategory?> onCategory;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.margin),
        children: [
          FilterChipButton(
            label: 'Semua',
            selected: !filter.isActive,
            onSelected: onClear,
          ),
          const SizedBox(width: MyOSSpace.sm),
          for (final status in GoalStatus.values) ...[
            FilterChipButton(
              label: '${status.label} ${view?.statusCounts[status] ?? 0}',
              selected: filter.status == status,
              onSelected: () => onStatus(filter.status == status ? null : status),
            ),
            const SizedBox(width: MyOSSpace.sm),
          ],
          Container(width: 1, height: 28, color: MyOSColors.border),
          const SizedBox(width: MyOSSpace.sm),
          for (final category in GoalCategory.values) ...[
            FilterChipButton(
              label: '${category.label} ${view?.categoryCounts[category] ?? 0}',
              selected: filter.category == category,
              onSelected: () =>
                  onCategory(filter.category == category ? null : category),
            ),
            const SizedBox(width: MyOSSpace.sm),
          ],
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.data});

  final GoalsView data;

  @override
  Widget build(BuildContext context) {
    final active = data.statusCounts[GoalStatus.active] ?? 0;
    final completed = data.statusCounts[GoalStatus.completed] ?? 0;
    final archived = data.statusCounts[GoalStatus.archived] ?? 0;

    return Row(
      children: [
        Expanded(
          child: AppWell(
            padding: const EdgeInsets.symmetric(
              horizontal: MyOSSpace.sm,
              vertical: 6,
            ),
            child: _Stat(label: 'Aktif', value: '$active'),
          ),
        ),
        const SizedBox(width: MyOSSpace.sm),
        Expanded(
          child: AppWell(
            padding: const EdgeInsets.symmetric(
              horizontal: MyOSSpace.sm,
              vertical: 6,
            ),
            child: _Stat(label: 'Selesai', value: '$completed'),
          ),
        ),
        const SizedBox(width: MyOSSpace.sm),
        Expanded(
          child: AppWell(
            padding: const EdgeInsets.symmetric(
              horizontal: MyOSSpace.sm,
              vertical: 6,
            ),
            child: _Stat(label: 'Arsip', value: '$archived'),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

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
        Text(value, style: MyOSText.dataMd.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({
    required this.filtered,
    required this.onClear,
    required this.onAdd,
  });

  final bool filtered;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            filtered ? 'TIDAK ADA TARGET COCOK' : 'BELUM ADA TARGET',
            style: MyOSText.labelSm,
          ),
          const SizedBox(height: MyOSSpace.sm),
          Text(
            filtered
                ? 'Filter status atau kategori yang aktif tidak menyisakan '
                      'target. Longgarkan filter untuk melihat sisanya.'
                : 'Buat target pertama untuk mulai melacak progres, tenggat, '
                      'dan milestone.',
            style: MyOSText.bodySm.copyWith(height: 18 / 12),
          ),
          const SizedBox(height: MyOSSpace.md),
          PanelActionButton(
            label: filtered ? 'Hapus filter' : 'Tambah target',
            onPressed: filtered ? onClear : onAdd,
          ),
        ],
      ),
    );
  }
}
