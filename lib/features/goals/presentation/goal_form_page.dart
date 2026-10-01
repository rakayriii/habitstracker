import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_detail_scaffold.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/forms.dart';
import '../../../domain/models/goal.dart';
import '../providers/goal_providers.dart';

/// Create or edit a goal. Validation happens here and again in the repository,
/// so an invalid row cannot reach SQLite even if this form is bypassed.
class GoalFormPage extends ConsumerStatefulWidget {
  const GoalFormPage({super.key, this.goalId});

  final String? goalId;

  bool get isEditing => goalId != null;

  @override
  ConsumerState<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends ConsumerState<GoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _target = TextEditingController();
  final _current = TextEditingController();

  GoalCategory _category = GoalCategory.finance;
  GoalPriority _priority = GoalPriority.medium;
  GoalStatus _status = GoalStatus.active;
  DateTime? _deadline;
  bool _busy = false;
  bool _loaded = false;

  String? _titleError;
  String? _targetError;
  String? _currentError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  void _hydrate(Goal goal) {
    if (_loaded) return;
    _loaded = true;
    _title.text = goal.title;
    _description.text = goal.description ?? '';
    _target.text = '${goal.targetValue}';
    _current.text = '${goal.currentValue}';
    _category = goal.category;
    _priority = goal.priority;
    _status = goal.status;
    _deadline = goal.deadline;
  }

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      title: widget.isEditing ? 'Edit target' : 'Target baru',
      bottomBar: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              label: widget.isEditing ? 'Simpan perubahan' : 'Simpan target',
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
            title: 'Target',
            children: [
              AppTextField(
                label: 'Judul',
                controller: _title,
                required: true,
                hint: 'mis. Dana darurat 12 bulan',
                error: _titleError,
                autofocus: true,
                onChanged: (_) => setState(() => _titleError = null),
              ),
              AppTextField(
                label: 'Deskripsi',
                controller: _description,
                maxLines: 3,
              ),
            ],
          ),
          FormSection(
            title: 'Klasifikasi',
            children: [
              AppChoiceField<GoalCategory>(
                label: 'Kategori',
                value: _category,
                options: GoalCategory.values,
                labelOf: (category) => category.label,
                hintOf: (category) =>
                    category == GoalCategory.finance ? 'rupiah' : 'hitungan',
                onChanged: (category) => setState(() => _category = category),
              ),
              AppChoiceField<GoalPriority>(
                label: 'Prioritas',
                value: _priority,
                options: GoalPriority.values,
                labelOf: (priority) => priority.label,
                onChanged: (priority) => setState(() => _priority = priority),
              ),
            ],
          ),
          FormSection(
            title: 'Nilai',
            children: [
              AppAmountField(
                label: 'Target',
                controller: _target,
                required: true,
                prefix: _category == GoalCategory.finance ? 'Rp' : '',
                error: _targetError,
                helper: _category == GoalCategory.finance
                    ? 'Nilai akhir yang ingin dicapai, dalam rupiah'
                    : 'Jumlah akhir, misalnya 20 buku atau 20 sesi lari',
                onChanged: (_) => setState(() => _targetError = null),
              ),
              AppAmountField(
                label: 'Nilai sekarang',
                controller: _current,
                prefix: _category == GoalCategory.finance ? 'Rp' : '',
                error: _currentError,
                onChanged: (_) => setState(() => _currentError = null),
              ),
              Text(
                'Progres dihitung sebagai nilai sekarang dibagi target, dan '
                'dibatasi maksimal 100%.',
                style: MyOSText.dataSm.copyWith(fontSize: 10, height: 14 / 10),
              ),
            ],
          ),
          FormSection(
            title: 'Waktu',
            children: [
              AppDateField(
                label: 'Tenggat',
                value: _deadline,
                onChanged: (value) => setState(() => _deadline = value),
                helper: 'Dipakai untuk menghitung sisa hari dan kebutuhan per '
                    'hari',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEdit(BuildContext context) {
    final goal = ref.watch(goalProvider(widget.goalId!));
    return AsyncContent<Goal?>(
      value: goal,
      onRetry: () => ref.invalidate(goalProvider(widget.goalId!)),
      builder: (data) {
        if (data == null) {
          return NotFoundPanel(what: 'Target ini', onBack: () => context.pop());
        }
        _hydrate(data);
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormSection(
                title: 'Target',
                children: [
                  AppTextField(
                    label: 'Judul',
                    controller: _title,
                    required: true,
                    error: _titleError,
                    onChanged: (_) => setState(() => _titleError = null),
                  ),
                  AppTextField(
                    label: 'Deskripsi',
                    controller: _description,
                    maxLines: 3,
                  ),
                ],
              ),
              FormSection(
                title: 'Klasifikasi',
                children: [
                  AppChoiceField<GoalCategory>(
                    label: 'Kategori',
                    value: _category,
                    options: GoalCategory.values,
                    labelOf: (category) => category.label,
                    onChanged: (category) => setState(() => _category = category),
                  ),
                  AppChoiceField<GoalPriority>(
                    label: 'Prioritas',
                    value: _priority,
                    options: GoalPriority.values,
                    labelOf: (priority) => priority.label,
                    onChanged: (priority) => setState(() => _priority = priority),
                  ),
                  AppChoiceField<GoalStatus>(
                    label: 'Status',
                    value: _status,
                    options: GoalStatus.values,
                    labelOf: (status) => status.label,
                    onChanged: (status) => setState(() => _status = status),
                  ),
                ],
              ),
              FormSection(
                title: 'Nilai',
                children: [
                  AppAmountField(
                    label: 'Target',
                    controller: _target,
                    required: true,
                    prefix: _category == GoalCategory.finance ? 'Rp' : '',
                    error: _targetError,
                    onChanged: (_) => setState(() => _targetError = null),
                  ),
                  AppAmountField(
                    label: 'Nilai sekarang',
                    controller: _current,
                    prefix: _category == GoalCategory.finance ? 'Rp' : '',
                    error: _currentError,
                    onChanged: (_) => setState(() => _currentError = null),
                  ),
                ],
              ),
              FormSection(
                title: 'Waktu',
                children: [
                  AppDateField(
                    label: 'Tenggat',
                    value: _deadline,
                    onChanged: (value) => setState(() => _deadline = value),
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
    final target = Fmt.parseAmount(_target.text);
    final current = Fmt.parseAmount(_current.text);
    setState(() {
      _titleError = _title.text.trim().isEmpty ? 'Judul wajib diisi' : null;
      _targetError = (target == null || target <= 0)
          ? 'Target harus lebih besar dari nol'
          : null;
      _currentError = current == null ? 'Nilai tidak valid' : null;
    });
    return _titleError == null && _targetError == null && _currentError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    final actions = ref.read(goalActionsProvider);
    final saved = await runGuarded(context, () async {
      if (widget.isEditing) {
        await actions.update(
          id: widget.goalId!,
          title: _title.text,
          category: _category,
          targetValue: Fmt.parseAmount(_target.text)!,
          currentValue: Fmt.parseAmount(_current.text) ?? 0,
          description: _description.text,
          deadline: _deadline,
          priority: _priority,
          status: _status,
        );
      } else {
        await actions.create(
          title: _title.text,
          category: _category,
          targetValue: Fmt.parseAmount(_target.text)!,
          currentValue: Fmt.parseAmount(_current.text) ?? 0,
          description: _description.text,
          deadline: _deadline,
          priority: _priority,
          status: _status,
        );
      }
    }, successMessage: widget.isEditing ? 'Target diperbarui' : 'Target disimpan');
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) context.pop();
  }
}
