import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_detail_scaffold.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/forms.dart';
import '../../../domain/models/project.dart';
import '../providers/project_providers.dart';

/// Create or edit a project. Tags are typed once as a comma separated list and
/// stored normalised, so a tag stays searchable on its own.
class ProjectFormPage extends ConsumerStatefulWidget {
  const ProjectFormPage({super.key, this.projectId});

  final String? projectId;

  bool get isEditing => projectId != null;

  @override
  ConsumerState<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends ConsumerState<ProjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _nextAction = TextEditingController();
  final _tags = TextEditingController();

  ProjectStatus _status = ProjectStatus.planned;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _deadline;
  bool _busy = false;
  bool _loaded = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _nextAction.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _hydrate(Project project) {
    if (_loaded) return;
    _loaded = true;
    _name.text = project.name;
    _description.text = project.description ?? '';
    _category.text = project.category;
    _nextAction.text = project.nextAction ?? '';
    _tags.text = project.tags.join(', ');
    _status = project.status;
    _priority = project.priority;
    _deadline = project.deadline;
  }

  List<String> get _tagList => [
    for (final tag in _tags.text.split(','))
      if (tag.trim().isNotEmpty) tag.trim(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      title: widget.isEditing ? 'Edit proyek' : 'Proyek baru',
      bottomBar: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              label: widget.isEditing ? 'Simpan perubahan' : 'Simpan proyek',
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ),
        ],
      ),
      child: widget.isEditing
          ? _buildEdit(context)
          : _buildCreate(context),
    );
  }

  Widget _buildCreate(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSection(
            title: 'Identitas',
            children: [
              AppTextField(
                label: 'Nama proyek',
                controller: _name,
                required: true,
                hint: 'mis. MediaVault',
                error: _nameError,
                autofocus: true,
                onChanged: (_) => setState(() => _nameError = null),
              ),
              AppTextField(
                label: 'Deskripsi',
                controller: _description,
                maxLines: 3,
              ),
              AppTextField(
                label: 'Kategori',
                controller: _category,
                hint: 'mis. System, Infra, Product, Web',
              ),
            ],
          ),
          FormSection(
            title: 'Status',
            children: [
              AppChoiceField<ProjectStatus>(
                label: 'Status',
                value: _status,
                options: ProjectStatus.values,
                labelOf: (status) => status.label,
                onChanged: (status) => setState(() => _status = status),
              ),
              AppChoiceField<TaskPriority>(
                label: 'Prioritas',
                value: _priority,
                options: TaskPriority.values,
                labelOf: (priority) => priority.label,
                onChanged: (priority) => setState(() => _priority = priority),
              ),
              AppDateField(
                label: 'Tenggat',
                value: _deadline,
                onChanged: (value) => setState(() => _deadline = value),
              ),
            ],
          ),
          FormSection(
            title: 'Eksekusi',
            children: [
              AppTextField(
                label: 'Langkah berikutnya',
                controller: _nextAction,
                maxLines: 2,
                helper: 'Kalau kosong, kartu akan memakai task terbuka '
                    'terdepan sebagai langkah berikutnya',
              ),
              AppTextField(
                label: 'Stack dan tag',
                controller: _tags,
                hint: 'Flutter, Riverpod, SQLite',
                helper: 'Pisahkan dengan koma',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEdit(BuildContext context) {
    final project = ref.watch(projectProvider(widget.projectId!));
    return AsyncContent<Project?>(
      value: project,
      onRetry: () => ref.invalidate(projectProvider(widget.projectId!)),
      builder: (data) {
        if (data == null) {
          return NotFoundPanel(
            what: 'Proyek ini',
            onBack: () => context.pop(),
          );
        }
        _hydrate(data);
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormSection(
                title: 'Identitas',
                children: [
                  AppTextField(
                    label: 'Nama proyek',
                    controller: _name,
                    required: true,
                    error: _nameError,
                    onChanged: (_) => setState(() => _nameError = null),
                  ),
                  AppTextField(
                    label: 'Deskripsi',
                    controller: _description,
                    maxLines: 3,
                  ),
                  AppTextField(
                    label: 'Kategori',
                    controller: _category,
                  ),
                ],
              ),
              FormSection(
                title: 'Status',
                children: [
                  AppChoiceField<ProjectStatus>(
                    label: 'Status',
                    value: _status,
                    options: ProjectStatus.values,
                    labelOf: (status) => status.label,
                    onChanged: (status) => setState(() => _status = status),
                  ),
                  AppChoiceField<TaskPriority>(
                    label: 'Prioritas',
                    value: _priority,
                    options: TaskPriority.values,
                    labelOf: (priority) => priority.label,
                    onChanged: (priority) => setState(() => _priority = priority),
                  ),
                  AppDateField(
                    label: 'Tenggat',
                    value: _deadline,
                    onChanged: (value) => setState(() => _deadline = value),
                  ),
                ],
              ),
              FormSection(
                title: 'Eksekusi',
                children: [
                  AppTextField(
                    label: 'Langkah berikutnya',
                    controller: _nextAction,
                    maxLines: 2,
                  ),
                  AppTextField(
                    label: 'Stack dan tag',
                    controller: _tags,
                    helper: 'Pisahkan dengan koma',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _validate() {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Nama proyek wajib diisi' : null;
    });
    return _nameError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    final actions = ref.read(projectActionsProvider);
    final saved = await runGuarded(context, () async {
      if (widget.isEditing) {
        await actions.update(
          id: widget.projectId!,
          name: _name.text,
          description: _description.text,
          status: _status,
          category: _category.text,
          priority: _priority,
          deadline: _deadline,
          nextAction: _nextAction.text,
          tags: _tagList,
        );
      } else {
        await actions.create(
          name: _name.text,
          description: _description.text,
          status: _status,
          category: _category.text,
          priority: _priority,
          deadline: _deadline,
          nextAction: _nextAction.text,
          tags: _tagList,
        );
      }
    }, successMessage: widget.isEditing ? 'Proyek diperbarui' : 'Proyek disimpan');
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) context.pop();
  }
}
