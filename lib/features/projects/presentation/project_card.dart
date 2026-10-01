import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_meter.dart';
import '../../../domain/models/project.dart';

BadgeTone statusTone(ProjectStatus status) => switch (status) {
  ProjectStatus.planned => BadgeTone.neutral,
  ProjectStatus.inDevelopment => BadgeTone.accent,
  ProjectStatus.onHold => BadgeTone.warning,
  ProjectStatus.shipped => BadgeTone.positive,
  ProjectStatus.archived => BadgeTone.neutral,
};

/// Full project card. Status, category, summary, delivery position, then the
/// two fields that decide what happens next: the next action and the work left.
/// Progress is the task ratio, computed in the domain model.
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.now});

  final Project project;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final shipped = !project.status.isOpen;
    return AppCard(
      onTap: () => context.push('/projects/${project.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  project.category.toUpperCase(),
                  style: MyOSText.labelSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MyOSSpace.sm),
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
            style: MyOSText.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            project.description ?? 'Tanpa deskripsi',
            style: MyOSText.bodySm.copyWith(
              fontSize: 11,
              height: 15 / 11,
              color: project.description == null
                  ? MyOSColors.textDisabled
                  : MyOSColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MyOSSpace.md),
          ProgressMeter(
            value: project.progress,
            color: shipped ? MyOSColors.positive : MyOSColors.accent,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  project.totalTasks == 0
                      ? 'Belum ada task'
                      : '${project.completedTasks}/${project.totalTasks} task selesai',
                  style: MyOSText.dataSm.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                shipped
                    ? 'Rilis ${Fmt.shortDate(project.deadline ?? project.updatedAt)}'
                    : 'sisa ${project.remainingTasks} task',
                style: MyOSText.dataSm,
                maxLines: 1,
              ),
            ],
          ),
          if (project.tags.isNotEmpty) ...[
            const SizedBox(height: MyOSSpace.md),
            Wrap(
              spacing: MyOSSpace.xs,
              runSpacing: MyOSSpace.xs,
              children: [
                for (final tag in project.tags)
                  AppBadge(label: tag, tone: BadgeTone.neutral, dense: true),
              ],
            ),
          ],
          const SizedBox(height: MyOSSpace.md),
          const Divider(height: 1),
          const SizedBox(height: MyOSSpace.sm),
          Row(
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
                      project.effectiveNextAction ?? 'Tidak ada pekerjaan terbuka',
                      style: MyOSText.bodySm.copyWith(
                        fontSize: 11,
                        height: 15 / 11,
                        color: project.effectiveNextAction == null
                            ? MyOSColors.textDisabled
                            : MyOSColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MyOSSpace.md),
              Text(
                'Diperbarui ${project.age(now)}',
                style: MyOSText.dataSm.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact project row for the Home rail.
class ProjectCompactRow extends StatelessWidget {
  const ProjectCompactRow({
    super.key,
    required this.project,
    required this.now,
  });

  final Project project;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final shipped = !project.status.isOpen;
    return AppWell(
      onTap: () => context.push('/projects/${project.id}'),
      padding: const EdgeInsets.all(MyOSSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  project.name,
                  style: MyOSText.bodyMd.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MyOSSpace.sm),
              AppBadge(
                label: project.status.label,
                tone: statusTone(project.status),
                dense: true,
              ),
              const SizedBox(width: MyOSSpace.sm),
              Text(
                Fmt.percent(project.progress),
                style: MyOSText.dataSm.copyWith(
                  color: MyOSColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ProgressMeter(
            value: project.progress,
            color: shipped ? MyOSColors.positive : MyOSColors.accent,
            height: 3,
          ),
          const SizedBox(height: 6),
          Text(
            '${project.category} · ${project.totalTasks} task'
            '${project.deadline == null ? '' : ' · ${Fmt.shortDate(project.deadline!)}'}'
            ' · ${project.age(now)}',
            style: MyOSText.dataSm.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
