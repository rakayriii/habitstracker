import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/models/project.dart';
import '../providers/project_providers.dart';
import 'project_card.dart';

/// Projects. Status is the organising axis: what a portfolio of work needs
/// first is to know which threads are moving, which are parked, and what the
/// next commit is.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final view = ref.watch(visibleProjectsProvider);
    final filter = ref.watch(projectFilterProvider);
    final notifier = ref.read(projectFilterProvider.notifier);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: MyOSSpace.xl),
        children: [
          AppPageHeader(
            workspace: 'Projects',
            title: 'Proyek',
            counter: '${view.value?.statusCounts[ProjectStatus.inDevelopment] ?? 0} jalan',
            meta: '${view.value?.openPoints ?? 0} task terbuka',
          ),
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.margin),
              children: [
                FilterChipButton(
                  label: 'Semua',
                  selected: !filter.isActive,
                  onSelected: notifier.clear,
                ),
                const SizedBox(width: MyOSSpace.sm),
                for (final status in ProjectStatus.values) ...[
                  FilterChipButton(
                    label: '${status.label} ${view.value?.statusCounts[status] ?? 0}',
                    selected: filter.status == status,
                    onSelected: () => notifier.setStatus(
                      filter.status == status ? null : status,
                    ),
                  ),
                  const SizedBox(width: MyOSSpace.sm),
                ],
              ],
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
                SectionHeader(
                  title: 'Active projects',
                  count: '${view.value?.openPoints ?? 0} task',
                  actionLabel: '+ Tambah',
                  onAction: () => context.push('/projects/new'),
                ),
                const SizedBox(height: MyOSSpace.sm),
                AsyncContent<ProjectsView>(
                  value: view,
                  onRetry: () => ref.invalidate(projectsProvider),
                  builder: (data) {
                    if (data.visible.isEmpty) {
                      return _EmptyProjects(
                        filtered: filter.isActive,
                        onClear: notifier.clear,
                        onAdd: () => context.push('/projects/new'),
                      );
                    }
                    return Column(
                      children: [
                        for (final project in data.visible) ...[
                          ProjectCard(project: project, now: now),
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

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({
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
            filtered ? 'TIDAK ADA PROYEK DI STATUS INI' : 'BELUM ADA PROYEK',
            style: MyOSText.labelSm,
          ),
          const SizedBox(height: MyOSSpace.sm),
          Text(
            filtered
                ? 'Tidak ada proyek berstatus itu saat ini. Pilih status lain '
                      'atau tampilkan semua.'
                : 'Buat proyek, lalu pecah menjadi task. Progres dihitung '
                      'dari task yang selesai, bukan dari angka yang '
                      'diketik manual.',
            style: MyOSText.bodySm.copyWith(height: 18 / 12),
          ),
          const SizedBox(height: MyOSSpace.md),
          PanelActionButton(
            label: filtered ? 'Tampilkan semua' : 'Tambah proyek',
            onPressed: filtered ? onClear : onAdd,
          ),
        ],
      ),
    );
  }
}
