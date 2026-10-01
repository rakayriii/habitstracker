import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_detail_scaffold.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/forms.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/transaction.dart';
import '../providers/finance_providers.dart';

/// Create or edit a transaction.
///
/// The type switch changes the form: a transfer asks for a second account and
/// is never counted as income or expense. Everything else is one shape.
class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({super.key, this.transactionId});

  final String? transactionId;

  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _category = TextEditingController();
  final _notes = TextEditingController();

  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  String? _accountId;
  String? _targetAccountId;
  bool _busy = false;
  bool _loaded = false;

  String? _amountError;
  String? _titleError;
  String? _accountError;
  String? _targetError;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _category.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _hydrate(Transaction transaction) {
    if (_loaded) return;
    _loaded = true;
    _amount.text = Fmt.group(transaction.amount);
    _title.text = transaction.title;
    _category.text = transaction.category;
    _notes.text = transaction.notes ?? '';
    _type = transaction.type;
    _date = transaction.date;
    _accountId = transaction.accountId;
    _targetAccountId = transaction.targetAccountId;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final rows = accounts.value;

    return AppDetailScaffold(
      title: widget.isEditing ? 'Edit transaksi' : 'Transaksi baru',
      bottomBar: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              label: widget.isEditing ? 'Simpan perubahan' : 'Catat transaksi',
              busy: _busy,
              onPressed: _busy || rows == null || rows.isEmpty
                  ? null
                  : _save,
            ),
          ),
        ],
      ),
      child: rows == null
          ? const LoadingLine()
          : rows.isEmpty
          ? _NoAccounts(onAdd: () => context.push('/finance/account/new'))
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isEditing)
                    _EditingBanner(
                      transactionId: widget.transactionId!,
                      rows: rows,
                      onHydrate: _hydrate,
                    ),
                  FormSection(
                    title: 'Jenis',
                    children: [
                      AppChoiceField<TransactionType>(
                        label: 'Tipe',
                        value: _type,
                        options: TransactionType.values,
                        labelOf: (type) => type.label,
                        onChanged: (type) => setState(() {
                          _type = type;
                          if (type != TransactionType.transfer) {
                            _targetAccountId = null;
                            _targetError = null;
                          }
                        }),
                      ),
                      Text(
                        _type.hint,
                        style: MyOSText.dataSm.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Nominal',
                    children: [
                      AppAmountField(
                        label: 'Nominal',
                        controller: _amount,
                        required: true,
                        error: _amountError,
                        onChanged: (_) {
                          if (_amountError != null) {
                            setState(() => _amountError = null);
                          }
                        },
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Keterangan',
                    children: [
                      AppTextField(
                        label: 'Judul',
                        controller: _title,
                        required: true,
                        hint: 'mis. Gaji bulanan',
                        error: _titleError,
                        onChanged: (_) => setState(() => _titleError = null),
                      ),
                      AppTextField(
                        label: 'Kategori',
                        controller: _category,
                        hint: 'mis. Groceries, Gaji, Utilitas',
                        helper: 'Bebas. Dipakai untuk mengelompokkan pengeluaran.',
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Akun',
                    children: [
                      AppChoiceField<String>(
                        label: _type == TransactionType.transfer
                            ? 'Dari akun'
                            : 'Akun',
                        value: _accountId ?? '',
                        options: [
                          for (final account in rows) account.id,
                        ],
                        labelOf: (id) =>
                            rows.firstWhere((a) => a.id == id).name,
                        hintOf: (id) {
                          final account = rows.firstWhere((a) => a.id == id);
                          return account.isLiability ? 'utang' : null;
                        },
                        onChanged: (id) => setState(() {
                          _accountId = id;
                          _accountError = null;
                          if (_targetAccountId == id) _targetAccountId = null;
                        }),
                        error: _accountError,
                      ),
                      if (_type == TransactionType.transfer) ...[
                        const SizedBox(height: MyOSSpace.md),
                        AppChoiceField<String>(
                          label: 'Ke akun',
                          value: _targetAccountId ?? '',
                          options: [
                            for (final account in rows)
                              if (account.id != _accountId) account.id,
                          ],
                          labelOf: (id) =>
                              rows.firstWhere((a) => a.id == id).name,
                          onChanged: (id) => setState(() {
                            _targetAccountId = id;
                            _targetError = null;
                          }),
                          error: _targetError,
                        ),
                      ],
                    ],
                  ),
                  FormSection(
                    title: 'Waktu',
                    children: [
                      AppDateField(
                        label: 'Tanggal',
                        value: _date,
                        allowClear: false,
                        onChanged: (value) =>
                            setState(() => _date = value ?? _date),
                      ),
                      AppTextField(
                        label: 'Catatan',
                        controller: _notes,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  bool _validate() {
    final amount = Fmt.parseAmount(_amount.text);
    setState(() {
      _amountError = (amount == null || amount <= 0)
          ? 'Nominal harus lebih besar dari nol'
          : null;
      _titleError = _title.text.trim().isEmpty
          ? 'Judul transaksi wajib diisi'
          : null;
      _accountError = _accountId == null ? 'Pilih akun' : null;
      _targetError = _type == TransactionType.transfer &&
              (_targetAccountId == null || _targetAccountId == _accountId)
          ? 'Pilih akun tujuan yang berbeda'
          : null;
    });
    return _amountError == null &&
        _titleError == null &&
        _accountError == null &&
        _targetError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    final actions = ref.read(financeActionsProvider);
    final amount = Fmt.parseAmount(_amount.text)!;
    final saved = await runGuarded(context, () async {
      if (widget.isEditing) {
        await actions.updateTransaction(
          id: widget.transactionId!,
          amount: amount,
          type: _type,
          accountId: _accountId!,
          targetAccountId: _targetAccountId,
          title: _title.text,
          category: _category.text,
          date: _date,
          notes: _notes.text,
        );
      } else {
        await actions.createTransaction(
          amount: amount,
          type: _type,
          accountId: _accountId!,
          targetAccountId: _targetAccountId,
          title: _title.text,
          category: _category.text,
          date: _date,
          notes: _notes.text,
        );
      }
    }, successMessage: widget.isEditing ? 'Transaksi diperbarui' : 'Transaksi tersimpan');
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) context.pop();
  }
}

/// Loads the stored transaction once and hands it to the form, so the caller
/// does not need its own AsyncValue branch.
class _EditingBanner extends ConsumerWidget {
  const _EditingBanner({
    required this.transactionId,
    required this.rows,
    required this.onHydrate,
  });

  final String transactionId;
  final List<Account> rows;
  final ValueChanged<Transaction> onHydrate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = ref
        .watch(
          transactionByIdProvider(transactionId),
        )
        .value;
    if (existing == null) {
      return const LoadingLine();
    }
    onHydrate(existing);
    return Padding(
      padding: const EdgeInsets.only(bottom: MyOSSpace.md),
      child: AppWell(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Mengubah transaksi ${Fmt.shortDate(existing.date)} · '
                '${existing.title}',
                style: MyOSText.dataSm.copyWith(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAccounts extends StatelessWidget {
  const _NoAccounts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Belum ada akun',
          style: MyOSText.headlineSm.copyWith(color: MyOSColors.textSecondary),
        ),
        const SizedBox(height: MyOSSpace.sm),
        Text(
          'Transaksi selalu menempel pada sebuah akun. Tambahkan akun dulu, '
          'lalu catat transaksi di dalamnya.',
          style: MyOSText.bodySm.copyWith(height: 18 / 12),
        ),
        const SizedBox(height: MyOSSpace.md),
        PrimaryButton(label: 'Tambah akun', onPressed: onAdd),
      ],
    );
  }
}
