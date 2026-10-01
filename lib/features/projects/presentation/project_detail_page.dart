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
import '../../../domain/models/project.dart';
import '../providers/project_providers.dart';
import 'project_card.dart';

/// Project detail. The task list is the progress: completing a checkbox moves
/// the meter here, on the list, and on Home, because all three read the same
/// rows.
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final project = ref.watch(projectProvider(projectId));

    return AppDetailScaffold(
      title: 'Proyek',
      subtitle: project.value?.name,
      actions: [
        HeaderAction(
          icon: Icons.edit_outlined,
          tooltip: 'Edit proyek',
          onPressed: project.value == null
              ? null
              : () => context.push('/projects/$projectId/edit'),
        ),
      ],
      bottomBar: project.value == null
          ? null
          : Row(
              children: [
                Expanded(
                  child: SecondaryAction(
                    label: 'Task baru',
                    icon: Icons.add_rounded,
                    onPressed: () => context.push('/projects/$projectId/task/new'),
                  ),
                ),
                const SizedBox(width: MyOSSpace.sm),
                Expanded(
                  child: DestructiveButton(
                    label: 'Hapus',
                    onPressed: () => _delete(context, ref),
                  ),
                ),
              ],
            ),
      child: AsyncContent<Project?>(
        value: project,
        onRetry: () => ref.invalidate(projectProvider(projectId)),
        builder: (data) {
          if (data == null) {
            return NotFoundPanel(
              what: 'Proyek ini',
              onBack: () => context.pop(),
            );
          }
          return _body(context, ref, data, now);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    Project project,
    DateTime now,
  ) {
    final open = project.tasks.where((task) => !task.isCompleted).toList();
    final done = project.tasks.where((task) => task.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppBadge(
                    label: project.category,
                    tone: BadgeTone.neutral,
                    dense: true,
                  ),
                  const SizedBox(width: MyOSSpace.xs),
                  AppBadge(
                    label: project.status.label,
                    tone: statusTone(project.status),
                    dense: true,
                  ),
                  const Spacer(),
                  Text(
                    Fmt.percent(project.progress),
                    style: MyOSText.dataSm.copyWith(
                      color: MyOSColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MyOSSpace.xs),
              Text(
                project.name,
                style: MyOSText.headlineSm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (project.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  project.description!,
                  style: MyOSText.bodySm.copyWith(fontSize: 11, height: 15 / 11),
                ),
              ],
              const SizedBox(height: MyOSSpace.md),
              ProgressMeter(value: project.progress),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${project.completedTasks}/${project.totalTasks} task selesai',
                      style: MyOSText.dataSm.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: MyOSSpace.sm),
                  Text(
                    'Diperbarui ${project.age(now)}',
                    style: MyOSText.dataSm.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MyOSSpace.md),
        Row(
          children: [
            Expanded(
              child: AppWell(
                padding: const EdgeInsets.symmetric(
                  horizontal: MyOSSpace.sm,
                  vertical: 6,
                ),
                child: _Stat(label: 'Terbuka', value: '${open.length}'),
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
            Expanded(
              child: AppWell(
                padding: const EdgeInsets.symmetric(
                  horizontal: MyOSSpace.sm,
                  vertical: 6,
                ),
                child: _Stat(label: 'Selesai', value: '${done.length}'),
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
            Expanded(
              child: AppWell(
                padding: const EdgeInsets.symmetric(
                  horizontal: MyOSSpace.sm,
                  vertical: 6,
                ),
                child: _Stat(
                  label: 'Tenggat',
                  value: project.deadline == null
                      ? 'Tidak ada'
                      : Fmt.dayMonth(project.deadline!),
                ),
              ),
            ),
          ],
        ),
        if (project.effectiveNextAction != null) ...[
          const SizedBox(height: MyOSSpace.md),
          AppWell(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BERIKUTNYA',
                        style: MyOSText.labelSm.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        project.effectiveNextAction!,
                        style: MyOSText.bodySm.copyWith(
                          fontSize: 11,
                          height: 15 / 11,
                          color: MyOSColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: MyOSSpace.lg),
        SectionRow(
          title: 'Task terbuka',
          count: '${open.length}',
          actionLabel: '+ Tambah',
          onAction: () => context.push('/projects/$projectId/task/new'),
        ),
        const SizedBox(height: MyOSSpace.sm),
        if (open.isEmpty)
          AppCard(
            child: Text(
              project.totalTasks == 0
                  ? 'Belum ada task. Tambahkan task agar progres bisa '
                        'dihitung dari pekerjaan yang benar-benar selesai.'
                  : 'Semua task sudah selesai.',
              style: MyOSText.bodySm.copyWith(height: 18 / 12),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.md),
            child: Column(
              children: [
                for (var i = 0; i < open.length; i++)
                  _TaskRow(
                    task: open[i],
                    divider: i < open.length - 1,
                    onToggle: (value) => _toggle(context, ref, open[i], value),
                    onEdit: () => context.push(
                      '/projects/$projectId/task/${open[i].id}',
                    ),
                  ),
              ],
            ),
          ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: MyOSSpace.lg),
          SectionRow(title: 'Task selesai', count: '${done.length}'),
          const SizedBox(height: MyOSSpace.sm),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.md),
            child: Column(
              children: [
                for (var i = 0; i < done.length; i++)
                  _TaskRow(
                    task: done[i],
                    divider: i < done.length - 1,
                    onToggle: (value) => _toggle(context, ref, done[i], value),
                    onEdit: () => context.push(
                      '/projects/$projectId/task/${done[i].id}',
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: MyOSSpace.lg),
        FormSection(
          title: 'Status proyek',
          children: [
            AppChoiceField<ProjectStatus>(
              label: 'Ubah status',
              value: project.status,
              options: ProjectStatus.values,
              labelOf: (status) => status.label,
              onChanged: (status) => _setStatus(context, ref, project, status),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    ProjectTask task,
    bool completed,
  ) {
    return runGuarded(
      context,
      () => ref
          .read(projectActionsProvider)
          .setTaskCompleted(task.id, completed),
      successMessage: completed ? 'Task diselesaikan' : 'Task dibuka lagi',
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    Project project,
    ProjectStatus status,
  ) {
    return runGuarded(
      context,
      () => ref.read(projectActionsProvider).setStatus(project.id, status),
      successMessage: 'Status diubah ke ${status.label.toLowerCase()}',
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hapus proyek?',
      message:
          'Proyek, seluruh task, dan tag-nya akan dihapus permanen dari '
          'perangkat ini.',
      confirmLabel: 'Hapus proyek',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runGuarded(
      context,
      () => ref.read(projectActionsProvider).delete(projectId),
      successMessage: 'Proyek dihapus',
    );
    if (ok && context.mounted) context.pop();
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
        Text(
          value,
          style: MyOSText.dataMd.copyWith(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class SectionRow extends StatelessWidget {
  const SectionRow({
    super.key,
    required this.title,
    required this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: MyOSText.headlineSm.copyWith(
              color: MyOSColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(count, style: MyOSText.dataSm),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: MyOSSpace.md),
          HeaderTextAction(label: actionLabel!, onPressed: onAction!),
        ],
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.divider,
    required this.onToggle,
    required this.onEdit,
  });

  final ProjectTask task;
  final bool divider;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final meta = [
      task.priority.label,
      if (task.dueDate != null) Fmt.shortDate(task.dueDate!),
      if (task.isOverdue) 'terlambat',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: MyOSSpace.sm),
          decoration: divider
              ? const BoxDecoration(
                  border: Border(bottom: BorderSide(color: MyOSColors.hairline)),
                )
              : null,
          child: Row(
            children: [
              AppCheckboxLike(
                checked: task.isCompleted,
                semanticLabel: task.title,
                onChanged: onToggle,
              ),
              const SizedBox(width: MyOSSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: MyOSText.bodyMd.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: task.isCompleted
                            ? MyOSColors.textMuted
                            : MyOSColors.textPrimary,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: MyOSColors.textDisabled,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: MyOSText.dataSm.copyWith(
                        fontSize: 10,
                        color: task.isOverdue
                            ? MyOSColors.warning
                            : MyOSColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
