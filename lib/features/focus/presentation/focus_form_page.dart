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
import '../../../core/widgets/forms.dart';
import '../../../domain/models/focus_item.dart';
import '../providers/focus_providers.dart';

/// Add or edit one focus item. The date defaults to today, which is what the
/// Home list reads, so a new item lands where the person expects it.
class FocusFormPage extends ConsumerStatefulWidget {
  const FocusFormPage({super.key, this.focusId});

  final String? focusId;

  bool get isEditing => focusId != null;

  @override
  ConsumerState<FocusFormPage> createState() => _FocusFormPageState();
}

class _FocusFormPageState extends ConsumerState<FocusFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();

  FocusPriority _priority = FocusPriority.p2;
  DateTime _date = DateTime.now();
  bool _busy = false;
  bool _loaded = false;
  String? _titleError;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      title: widget.isEditing ? 'Edit fokus' : 'Fokus baru',
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
              label: widget.isEditing ? 'Simpan perubahan' : 'Tambah fokus',
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ),
        ],
      ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final item = widget.isEditing
        ? ref.watch(focusItemProvider(widget.focusId!)).value
        : null;
    if (widget.isEditing && item != null && !_loaded) {
      _loaded = true;
      _title.text = item.title;
      _notes.text = item.notes ?? '';
      _priority = item.priority;
      _date = item.date;
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSection(
            title: 'Rencana',
            children: [
              AppTextField(
                label: 'Judul',
                controller: _title,
                required: true,
                hint: 'mis. Review runbook cutover',
                error: _titleError,
                autofocus: true,
                onChanged: (_) => setState(() => _titleError = null),
              ),
              AppChoiceField<FocusPriority>(
                label: 'Prioritas',
                value: _priority,
                options: FocusPriority.values,
                labelOf: (priority) => priority.label,
                hintOf: (priority) => priority == FocusPriority.p1
                    ? 'tinggi'
                    : priority == FocusPriority.p2
                    ? 'sedang'
                    : 'rendah',
                onChanged: (priority) => setState(() => _priority = priority),
              ),
              AppDateField(
                label: 'Tanggal',
                value: _date,
                allowClear: false,
                onChanged: (value) => setState(() => _date = value ?? _date),
                helper: 'Item hanya muncul di Hari Fokus pada tanggal yang '
                    'sama',
              ),
            ],
          ),
          FormSection(
            title: 'Catatan',
            children: [
              AppTextField(
                label: 'Detail',
                controller: _notes,
                maxLines: 3,
              ),
            ],
          ),
          if (widget.isEditing)
            _StatusLine(focusId: widget.focusId!),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = 'Judul fokus wajib diisi');
      return;
    }
    setState(() => _busy = true);
    final actions = ref.read(focusActionsProvider);
    final saved = await runGuarded(context, () async {
      if (widget.isEditing) {
        await actions.update(
          id: widget.focusId!,
          title: _title.text,
          priority: _priority,
          date: _date,
          notes: _notes.text,
        );
      } else {
        await actions.create(
          title: _title.text,
          priority: _priority,
          date: _date,
          notes: _notes.text,
        );
      }
    }, successMessage: widget.isEditing ? 'Fokus diperbarui' : 'Fokus ditambahkan');
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hapus fokus?',
      message: '"${_title.text}" akan dihapus dari daftar hari ini.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(focusActionsProvider).delete(widget.focusId!),
      successMessage: 'Fokus dihapus',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }
}

/// Completion state of the edited item, read live from the database.
class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.focusId});

  final String focusId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(focusItemProvider(focusId)).value;
    if (item == null) return const SizedBox.shrink();
    return AppWell(
      child: Text(
        item.isCompleted
            ? 'Ditandai selesai ${Fmt.shortDate(item.completedAt!)}'
            : 'Belum ditandai selesai',
        style: MyOSText.dataSm.copyWith(fontSize: 10, height: 14 / 10),
      ),
    );
  }
}
