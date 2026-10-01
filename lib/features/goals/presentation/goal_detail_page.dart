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
import '../../../core/widgets/forms.dart';
import '../../../core/widgets/progress_meter.dart';
import '../../../domain/models/goal.dart';
import '../providers/goal_providers.dart';
import 'goal_card.dart';

/// Goal detail. Progress is read, never typed: the meter, the percentage, the
/// remaining amount and the required daily figure all come from the same
/// stored current value.
class GoalDetailPage extends ConsumerStatefulWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends ConsumerState<GoalDetailPage> {
  final _progress = TextEditingController();
  final _milestoneTitle = TextEditingController();
  final _milestoneValue = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _progress.dispose();
    _milestoneTitle.dispose();
    _milestoneValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(goalProvider(widget.goalId));

    return AppDetailScaffold(
      title: 'Target',
      subtitle: goal.value?.title,
      actions: [
        HeaderAction(
          icon: Icons.edit_outlined,
          tooltip: 'Edit target',
          onPressed: goal.value == null
              ? null
              : () => context.push('/goals/${widget.goalId}/edit'),
        ),
      ],
      bottomBar: goal.value == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: SecondaryAction(
                    label: 'Selesai',
                    icon: Icons.check_rounded,
                    onPressed: goal.value!.status == GoalStatus.completed
                        ? null
                        : _complete,
                  ),
                ),
                const SizedBox(width: MyOSSpace.sm),
                Expanded(
                  child: DestructiveButton(
                    label: 'Hapus',
                    onPressed: _busy ? null : _delete,
                  ),
                ),
              ],
            ),
      child: AsyncContent<Goal?>(
        value: goal,
        onRetry: () => ref.invalidate(goalProvider(widget.goalId)),
        builder: (data) {
          if (data == null) {
            return NotFoundPanel(
              what: 'Target ini',
              onBack: () => context.pop(),
            );
          }
          return _body(context, data);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Goal goal) {
    final pair = goalValuePair(goal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: AppBadge(
                      label: goal.category.label,
                      tone: BadgeTone.neutral,
                      dense: true,
                    ),
                  ),
                  const SizedBox(width: MyOSSpace.xs),
                  AppBadge(
                    label: goal.status.label,
                    tone: goalStatusTone(goal.status),
                    dense: true,
                  ),
                  const SizedBox(width: MyOSSpace.sm),
                  Flexible(
                    child: Text(
                      goal.pace,
                      style: MyOSText.dataSm,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MyOSSpace.xs),
              Text(
                goal.title,
                style: MyOSText.headlineSm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (goal.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  goal.description!,
                  style: MyOSText.bodySm.copyWith(fontSize: 11, height: 15 / 11),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: MyOSSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      pair.current,
                      style: MyOSText.dataLg,
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
              ProgressMeter(value: goal.progress),
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
                  const Spacer(),
                  Text(
                    'Prioritas ${goal.priority.label.toLowerCase()}',
                    style: MyOSText.dataSm.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MyOSSpace.lg),
        _PacePanel(goal: goal),
        const SizedBox(height: MyOSSpace.lg),
        _ProgressEditor(
          controller: _progress,
          goal: goal,
          busy: _busy,
          onSubmit: (value) => _setProgress(goal, value),
        ),
        const SizedBox(height: MyOSSpace.lg),
        _MilestoneSection(
          goal: goal,
          titleController: _milestoneTitle,
          valueController: _milestoneValue,
          onToggle: (milestone, done) => _toggleMilestone(milestone, done),
          onDelete: _deleteMilestone,
          onAdd: _addMilestone,
        ),
        const SizedBox(height: MyOSSpace.lg),
        FormSection(
          title: 'Status',
          children: [
            AppChoiceField<GoalStatus>(
              label: 'Ubah status',
              value: goal.status,
              options: GoalStatus.values,
              labelOf: (status) => status.label,
              onChanged: (status) => _setStatus(goal, status),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setProgress(Goal goal, int value) async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(goalActionsProvider).setProgress(goal.id, value),
      successMessage: 'Progres diperbarui',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _progress.clear();
  }

  Future<void> _setStatus(Goal goal, GoalStatus status) async {
    await runGuarded(
      context,
      () => ref.read(goalActionsProvider).setStatus(goal.id, status),
      successMessage: 'Status diubah ke ${status.label.toLowerCase()}',
    );
  }

  Future<void> _complete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Tandai selesai?',
      message:
          'Progres akan diisi ke nilai target dan semua milestone ditandai '
          'tercapai. Bisa diubah lagi nanti dari menu status.',
      confirmLabel: 'Tandai selesai',
    );
    if (!confirmed || !mounted) return;
    final ok = await runGuarded(
      context,
      () => ref.read(goalActionsProvider).complete(widget.goalId),
      successMessage: 'Target ditandai selesai',
    );
    if (!ok && mounted) return;
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hapus target?',
      message:
          'Target dan seluruh milestone-nya akan dihapus permanen dari '
          'perangkat ini.',
      confirmLabel: 'Hapus target',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(goalActionsProvider).delete(widget.goalId),
      successMessage: 'Target dihapus',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }

  Future<void> _addMilestone(Goal goal) async {
    final title = _milestoneTitle.text.trim();
    final value = Fmt.parseAmount(_milestoneValue.text);
    if (title.isEmpty || value == null || value <= 0) {
      showFeedback(
        context,
        'Nama milestone dan nilai yang lebih besar dari nol wajib diisi',
        isError: true,
      );
      return;
    }
    final ok = await runGuarded(
      context,
      () => ref
          .read(goalActionsProvider)
          .addMilestone(goal.id, title: title, targetValue: value),
      successMessage: 'Milestone ditambahkan',
    );
    if (!ok || !mounted) return;
    _milestoneTitle.clear();
    _milestoneValue.clear();
  }

  Future<void> _toggleMilestone(GoalMilestone milestone, bool done) async {
    await runGuarded(
      context,
      () => ref
          .read(goalActionsProvider)
          .setMilestoneCompleted(milestone.id, done),
      successMessage: done ? 'Milestone dicapai' : 'Milestone dibuka lagi',
    );
  }

  Future<void> _deleteMilestone(GoalMilestone milestone) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hapus milestone?',
      message: '"${milestone.title}" akan dihapus dari daftar milestone.',
    );
    if (!confirmed || !mounted) return;
    await runGuarded(
      context,
      () => ref.read(goalActionsProvider).deleteMilestone(milestone.id),
      successMessage: 'Milestone dihapus',
    );
  }
}

/// Remaining amount, days left and the daily figure that closes the gap. Every
/// number is derived; nothing is estimated by hand.
class _PacePanel extends StatelessWidget {
  const _PacePanel({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final unit = goal.isCurrency ? (int v) => Fmt.idrCompact(v) : (int v) => '$v';
    final done = goal.status == GoalStatus.completed;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: MyOSSpace.md,
        vertical: MyOSSpace.sm,
      ),
      child: Column(
        children: [
          _PaceRow(
            label: 'Sisa nilai',
            value: unit(goal.remainingValue),
            valueColor: goal.remainingValue == 0
                ? MyOSColors.positive
                : null,
          ),
          _PaceRow(
            label: 'Sisa waktu',
            value: goal.deadline == null
                ? 'Tanpa tenggat'
                : goal.daysLeft < 0
                ? 'Terlambat ${-goal.daysLeft} hari'
                : '${goal.daysLeft} hari',
            valueColor: goal.isOverdue ? MyOSColors.negative : null,
          ),
          _PaceRow(
            label: 'Butuh per hari',
            value: done || goal.deadline == null
                ? 'Tidak dihitung'
                : unit(goal.requiredPerDay),
          ),
          _PaceRow(
            label: 'Butuh per bulan',
            value: done || goal.deadline == null
                ? 'Tidak dihitung'
                : unit(goal.requiredPerMonth),
          ),
          _PaceRow(
            label: 'Kecepatan',
            value: goal.deadline == null
                ? 'Tidak dihitung'
                : goal.isOnTrack
                ? 'Mengejar tenggat'
                : 'Di belakang tenggat',
            valueColor: goal.deadline == null
                ? null
                : goal.isOnTrack
                ? MyOSColors.positive
                : MyOSColors.warning,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _PaceRow extends StatelessWidget {
  const _PaceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.last = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: MyOSSpace.sm),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: MyOSColors.hairline)),
            ),
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
              style: MyOSText.dataMd.copyWith(fontSize: 13, color: valueColor),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress editing. The field starts empty so it never looks like a value the
/// user is about to overwrite by accident.
class _ProgressEditor extends StatelessWidget {
  const _ProgressEditor({
    required this.controller,
    required this.goal,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final Goal goal;
  final bool busy;
  final ValueChanged<int> onSubmit;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Perbarui progres',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppAmountField(
                label: 'Nilai baru',
                controller: controller,
                prefix: goal.isCurrency ? 'Rp' : '',
                helper: goal.isCurrency
                    ? 'Target ${Fmt.idr(goal.targetValue)}'
                    : 'Target ${goal.targetValue}',
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: PrimaryButton(
                label: 'Simpan',
                dense: true,
                busy: busy,
                onPressed: busy
                    ? null
                    : () {
                        final value = Fmt.parseAmount(controller.text);
                        if (value == null) {
                          showFeedback(
                            context,
                            'Masukkan nilai yang valid',
                            isError: true,
                          );
                          return;
                        }
                        onSubmit(value);
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MilestoneSection extends StatelessWidget {
  const _MilestoneSection({
    required this.goal,
    required this.titleController,
    required this.valueController,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
  });

  final Goal goal;
  final TextEditingController titleController;
  final TextEditingController valueController;
  final Future<void> Function(GoalMilestone, bool) onToggle;
  final Future<void> Function(GoalMilestone) onDelete;
  final Future<void> Function(Goal goal) onAdd;

  @override
  Widget build(BuildContext context) {
    final unit = goal.isCurrency
        ? (int v) => Fmt.idrCompact(v)
        : (int v) => '$v';

    return FormSection(
      title: 'Milestone',
      children: [
        if (goal.milestones.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: MyOSSpace.sm),
            child: Text(
              'Belum ada milestone. Tambahkan ambang nilai, misalnya 25%, 50%, '
              'dan 100% dari target.',
              style: MyOSText.dataSm.copyWith(fontSize: 10, height: 14 / 10),
            ),
          )
        else
          for (final milestone in goal.milestones)
            _MilestoneRow(
              milestone: milestone,
              unit: unit,
              reached: goal.currentValue >= milestone.targetValue,
              onToggle: (done) => onToggle(milestone, done),
              onDelete: () => onDelete(milestone),
            ),
        const SizedBox(height: MyOSSpace.sm),
        AppTextField(
          label: 'Milestone baru',
          controller: titleController,
          hint: 'mis. Dana darurat 3 bulan',
        ),
        const SizedBox(height: MyOSSpace.sm),
        Row(
          children: [
            Expanded(
              child: AppAmountField(
                label: 'Nilai ambang',
                controller: valueController,
                prefix: goal.isCurrency ? 'Rp' : '',
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: PrimaryButton(
                label: 'Tambah',
                dense: true,
                onPressed: () => onAdd(goal),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.unit,
    required this.reached,
    required this.onToggle,
    required this.onDelete,
  });

  final GoalMilestone milestone;
  final String Function(int) unit;
  final bool reached;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MyOSColors.hairline)),
      ),
      child: Row(
        children: [
          AppCheckboxLike(
            checked: milestone.isCompleted,
            semanticLabel: milestone.title,
            onChanged: onToggle,
          ),
          const SizedBox(width: MyOSSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: MyOSText.bodyMd.copyWith(
                    fontSize: 13,
                    color: milestone.isCompleted
                        ? MyOSColors.textMuted
                        : MyOSColors.textPrimary,
                    decoration: milestone.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: MyOSColors.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  reached
                      ? 'Tercapai · ${unit(milestone.targetValue)}'
                      : 'Belum tercapai · ${unit(milestone.targetValue)}',
                  style: MyOSText.dataSm.copyWith(
                    fontSize: 10,
                    color: reached ? MyOSColors.positive : MyOSColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          HeaderTextAction(
            label: 'Hapus',
            tone: MyOSActionTone.critical,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
