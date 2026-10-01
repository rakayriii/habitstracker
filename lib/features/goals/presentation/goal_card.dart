import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_meter.dart';
import '../../../domain/models/goal.dart';

/// Goal values are rupiah for finance goals and plain counts otherwise. The
/// unit is named once, on the target, so a pair never reads "14 sesi dari 20
/// sesi".
({String current, String rest}) goalValuePair(Goal goal) {
  return goal.isCurrency
      ? (
          current: Fmt.idrCompact(goal.currentValue),
          rest: ' dari ${Fmt.idrCompact(goal.targetValue)}',
        )
      : (
          current: '${goal.currentValue}',
          rest: ' dari ${goal.targetValue}',
        );
}

String goalValueShort(Goal goal) {
  return goal.isCurrency
      ? '${Fmt.idrCompact(goal.currentValue)} / ${Fmt.idrCompact(goal.targetValue)}'
      : '${goal.currentValue} / ${goal.targetValue}';
}

/// Full goal card. Category, title, position against target, progress, then the
/// operational metadata a review needs: pace, deadline, milestones.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final pair = goalValuePair(goal);
    final done = goal.status == GoalStatus.completed;
    final archived = goal.status == GoalStatus.archived;
    final tone = done
        ? BadgeTone.positive
        : archived
        ? BadgeTone.neutral
        : goal.isOnTrack
        ? BadgeTone.positive
        : BadgeTone.warning;

    return AppCard(
      onTap: () => context.push('/goals/${goal.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  goal.category.label.toUpperCase(),
                  style: MyOSText.labelSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MyOSSpace.sm),
              Text(
                goal.priority.label.toUpperCase(),
                style: MyOSText.dataSm.copyWith(
                  fontSize: 10,
                  color: MyOSColors.textDisabled,
                ),
              ),
              const Spacer(),
              AppBadge(label: goal.pace, tone: tone, dense: true),
            ],
          ),
          const SizedBox(height: MyOSSpace.xs),
          Text(
            goal.title,
            style: MyOSText.cardTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MyOSSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  pair.current,
                  style: MyOSText.dataMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  pair.rest,
                  style: MyOSText.dataSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: MyOSSpace.sm),
          ProgressMeter(
            value: goal.progress,
            color: done ? MyOSColors.positive : MyOSColors.accent,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                Fmt.percent(goal.progress),
                style: MyOSText.dataSm.copyWith(
                  color: MyOSColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: MyOSSpace.sm),
              Text(
                'sisa ${goal.isCurrency ? Fmt.idrCompact(goal.remainingValue) : goal.remainingValue}',
                style: MyOSText.dataSm.copyWith(fontSize: 10),
              ),
              const SizedBox(width: MyOSSpace.sm),
              Expanded(
                child: Text(
                  goal.milestones.isEmpty
                      ? 'Belum ada milestone'
                      : '${goal.completedMilestones}/${goal.milestones.length} milestone',
                  style: MyOSText.dataSm,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: MyOSSpace.md),
          const Divider(height: 1),
          const SizedBox(height: MyOSSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.deadline == null
                      ? 'Tanpa tenggat'
                      : 'Tenggat ${Fmt.shortDate(goal.deadline!)}',
                  style: MyOSText.dataSm.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (goal.requiredPerDay > 0 && !done)
                Text(
                  'butuh ${goal.isCurrency ? Fmt.idrCompact(goal.requiredPerDay) : goal.requiredPerDay}/hari',
                  style: MyOSText.dataSm.copyWith(fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact goal row for the Home rail: no card chrome, so three of them still
/// read as one block.
class GoalCompactRow extends StatelessWidget {
  const GoalCompactRow({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return AppWell(
      onTap: () => context.push('/goals/${goal.id}'),
      padding: const EdgeInsets.all(MyOSSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: MyOSText.bodyMd.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MyOSSpace.sm),
              Text(
                Fmt.percent(goal.progress),
                style: MyOSText.dataSm.copyWith(
                  color: MyOSColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ProgressMeter(
            value: goal.progress,
            color: goal.isOnTrack ? MyOSColors.accent : MyOSColors.warning,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${goal.category.label.toUpperCase()} · '
                  '${goalValueShort(goal)}',
                  style: MyOSText.dataSm.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MyOSSpace.sm),
              Text(goal.pace, style: MyOSText.dataSm.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status colour, defined once so the list and the detail screen agree.
BadgeTone goalStatusTone(GoalStatus status) => switch (status) {
  GoalStatus.active => BadgeTone.accent,
  GoalStatus.completed => BadgeTone.positive,
  GoalStatus.archived => BadgeTone.neutral,
};
