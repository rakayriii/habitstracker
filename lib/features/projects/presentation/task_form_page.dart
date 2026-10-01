import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/design_tokens.dart';
import '../../../core/widgets/app_detail_scaffold.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/forms.dart';
import '../../../domain/models/project.dart';
import '../providers/project_providers.dart';

/// Create or edit one task inside a project. The task is the unit of progress,
/// so this form is deliberately small: title, priority, due date, note.
class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({
    super.key,
    required this.projectId,
    this.taskId,
  });

  final String projectId;
  final String? taskId;

  bool get isEditing => taskId != null;

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _busy = false;
  bool _loaded = false;
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrate(ProjectTask task) {
    if (_loaded) return;
    _loaded = true;
    _title.text = task.title;
    _description.text = task.description ?? '';
    _priority = task.priority;
    _dueDate = task.dueDate;
  }

  /// Reads the task out of the project it belongs to, so this page does not
  /// need its own query.
  ProjectTask? get _existing {
    final project = ref.read(projectProvider(widget.projectId)).value;
    if (project == null || widget.taskId == null) return null;
    return project.tasks
        .where((task) => task.id == widget.taskId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      title: widget.isEditing ? 'Edit task' : 'Task baru',
      bottomBar: Row(
        children: [
          if (widget.isEditing) ...[
            Expanded(
              child: DestructiveButton(
                label: 'Hapus',
                onPressed: _busy ? null : _delete,
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
          ],
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: widget.isEditing ? 'Simpan perubahan' : 'Tambah task',
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ),
        ],
      ),
      child: widget.isEditing ? _buildEdit() : _buildCreate(),
    );
  }

  Widget _buildCreate() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSection(
            title: 'Task',
            children: [
              AppTextField(
                label: 'Judul task',
                controller: _title,
                required: true,
                hint: 'mis. Cutover runbook',
                error: _titleError,
                autofocus: true,
                onChanged: (_) => setState(() => _titleError = null),
              ),
              AppTextField(
                label: 'Catatan',
                controller: _description,
                maxLines: 3,
              ),
            ],
          ),
          FormSection(
            title: 'Jadwal',
            children: [
              AppChoiceField<TaskPriority>(
                label: 'Prioritas',
                value: _priority,
                options: TaskPriority.values,
                labelOf: (priority) => priority.label,
                onChanged: (priority) => setState(() => _priority = priority),
              ),
              AppDateField(
                label: 'Jatuh tempo',
                value: _dueDate,
                onChanged: (value) => setState(() => _dueDate = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEdit() {
    final task = _existing;
    if (task == null) {
      final loading = ref.watch(projectProvider(widget.projectId));
      if (loading.isLoading) return const LoadingLine();
      return NotFoundPanel(what: 'Task ini', onBack: () => Navigator.of(context).pop());
    }
    _hydrate(task);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSection(
            title: 'Task',
            children: [
              AppTextField(
                label: 'Judul task',
                controller: _title,
                required: true,
                error: _titleError,
                onChanged: (_) => setState(() => _titleError = null),
              ),
              AppTextField(
                label: 'Catatan',
                controller: _description,
                maxLines: 3,
              ),
            ],
          ),
          FormSection(
            title: 'Jadwal',
            children: [
              AppChoiceField<TaskPriority>(
                label: 'Prioritas',
                value: _priority,
                options: TaskPriority.values,
                labelOf: (priority) => priority.label,
                onChanged: (priority) => setState(() => _priority = priority),
              ),
              AppDateField(
                label: 'Jatuh tempo',
                value: _dueDate,
                onChanged: (value) => setState(() => _dueDate = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = 'Judul task wajib diisi');
      return;
    }
    setState(() => _busy = true);
    final actions = ref.read(projectActionsProvider);
    final saved = await runGuarded(context, () async {
      if (widget.isEditing) {
        await actions.updateTask(
          taskId: widget.taskId!,
          title: _title.text,
          description: _description.text,
          priority: _priority,
          dueDate: _dueDate,
        );
      } else {
        await actions.addTask(
          widget.projectId,
          title: _title.text,
          description: _description.text,
          priority: _priority,
          dueDate: _dueDate,
        );
      }
    }, successMessage: widget.isEditing ? 'Task diperbarui' : 'Task ditambahkan');
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hapus task?',
      message:
          'Progres proyek dihitung dari task yang tersisa, jadi menghapus '
          'task akan mengubah persentase progres.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(projectActionsProvider).deleteTask(widget.taskId!),
      successMessage: 'Task dihapus',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }
}
