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
import '../../../domain/models/account.dart';
import '../providers/finance_providers.dart';

/// Create or edit an account. One screen for both, because the fields are the
/// same and a separate edit form would be a copy with a different title.
///
/// The balance is never stored. When creating, the opening balance is recorded
/// as a ledger entry. When editing, the field states the balance the account
/// should have and the difference from the one the ledger implies is recorded
/// as an adjustment, so a correction stays explainable.
class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key, this.accountId});

  final String? accountId;

  bool get isEditing => accountId != null;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _initialBalance = TextEditingController();
  final _notes = TextEditingController();

  AccountType _type = AccountType.bank;
  bool _isLiability = false;
  bool _busy = false;
  bool _loaded = false;
  String? _nameError;
  String? _balanceError;

  @override
  void dispose() {
    _name.dispose();
    _initialBalance.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Fills the form from the stored record. Runs once per account id.
  void _hydrate(Account account) {
    if (_loaded) return;
    _loaded = true;
    _name.text = account.name;
    _notes.text = account.notes ?? '';
    _type = account.type;
    _isLiability = account.isLiability;
    // Prefilled with the current balance, so saving an untouched form corrects
    // nothing. An overdrawn asset starts empty: the amount field only takes
    // non-negative numbers, and showing its magnitude would ask for the
    // opposite of the correction.
    _initialBalance.text =
        account.balance < 0 ? '' : Fmt.group(account.balance);
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (widget.isEditing) {
      actions.add(
        HeaderAction(
          icon: Icons.archive_outlined,
          tooltip: 'Arsipkan akun',
          onPressed: _busy ? null : () => _toggleArchive(),
        ),
      );
    }

    return AppDetailScaffold(
      title: widget.isEditing ? 'Edit akun' : 'Akun baru',
      actions: actions,
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
              label: widget.isEditing ? 'Simpan perubahan' : 'Simpan akun',
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ),
        ],
      ),
      child: widget.isEditing
          ? _buildEditBody(context)
          : _buildCreateBody(context),
    );
  }

  Widget _buildCreateBody(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSection(
            title: 'Identitas',
            children: [
              AppTextField(
                label: 'Nama akun',
                controller: _name,
                required: true,
                hint: 'mis. Tabungan Utama',
                error: _nameError,
                autofocus: true,
                onChanged: (_) => setState(() => _nameError = null),
              ),
              AppChoiceField<AccountType>(
                label: 'Jenis',
                value: _type,
                options: AccountType.values,
                labelOf: (type) => type.label,
                hintOf: (type) => type == AccountType.creditCard ? 'utang' : null,
                onChanged: (type) => setState(() {
                  _type = type;
                  // A credit card is a liability by nature; the switch below
                  // stays editable so the choice is never made silently.
                  if (type == AccountType.creditCard) _isLiability = true;
                }),
              ),
              AppSwitchField(
                label: 'Perlakukan sebagai kewajiban',
                helper: 'Saldo akun ini mengurangi net worth, bukan menambah',
                value: _isLiability,
                onChanged: (value) => setState(() => _isLiability = value),
              ),
            ],
          ),
          FormSection(
            title: 'Saldo awal',
            children: [
              AppAmountField(
                label: 'Saldo awal',
                controller: _initialBalance,
                error: _balanceError,
                helper: _isLiability
                    ? 'Nominal yang masih terutang saat akun dibuat'
                    : 'Nominal yang tercatat saat akun dibuat',
              ),
              Text(
                'Saldo awal disimpan sebagai transaksi "Saldo awal", bukan '
                'ditulis langsung ke saldo. Dengan begitu setiap angka pada '
                'saldo punya transaksi yang bisa dibuka.',
                style: MyOSText.dataSm.copyWith(fontSize: 10, height: 14 / 10),
              ),
            ],
          ),
          FormSection(
            title: 'Catatan',
            children: [
              AppTextField(
                label: 'Catatan',
                controller: _notes,
                maxLines: 3,
                hint: 'Nomor rekening,Obligasi, atau catatan lain',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditBody(BuildContext context) {
    final account = ref.watch(accountProvider(widget.accountId!));
    return AsyncContent<Account?>(
      value: account,
      onRetry: () => ref.invalidate(accountProvider(widget.accountId!)),
      builder: (data) {
        if (data == null) {
          return NotFoundPanel(
            what: 'Akun ini',
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
                title: 'Saldo',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fmt.idr(data.balance),
                          style: MyOSText.dataLg,
                        ),
                      ),
                      Text(
                        data.isLiability ? 'Utang' : 'Dimiliki',
                        style: MyOSText.dataSm,
                      ),
                    ],
                  ),
                  const SizedBox(height: MyOSSpace.md),
                  AppAmountField(
                    label: 'Saldo saat ini',
                    controller: _initialBalance,
                    error: _balanceError,
                    helper: _balanceHelper(data),
                  ),
                  Text(
                    'Saldo tetap dihitung dari transaksi. Selisih antara angka '
                    'di atas dengan nominal yang Anda isi dicatat sebagai '
                    'transaksi penyesuaian, jadi setiap rupiah pada saldo '
                    'punya transaksi yang bisa dibuka.',
                    style: MyOSText.dataSm.copyWith(
                      fontSize: 10,
                      height: 14 / 10,
                    ),
                  ),
                ],
              ),
              FormSection(
                title: 'Identitas',
                children: [
                  AppTextField(
                    label: 'Nama akun',
                    controller: _name,
                    required: true,
                    error: _nameError,
                    onChanged: (_) => setState(() => _nameError = null),
                  ),
                  AppChoiceField<AccountType>(
                    label: 'Jenis',
                    value: _type,
                    options: AccountType.values,
                    labelOf: (type) => type.label,
                    onChanged: (type) => setState(() => _type = type),
                  ),
                  AppSwitchField(
                    label: 'Perlakukan sebagai kewajiban',
                    helper: 'Saldo akun ini mengurangi net worth',
                    value: _isLiability,
                    onChanged: (value) => setState(() => _isLiability = value),
                  ),
                ],
              ),
              FormSection(
                title: 'Catatan',
                children: [
                  AppTextField(
                    label: 'Catatan',
                    controller: _notes,
                    maxLines: 3,
                  ),
                ],
              ),
              if (data.isArchived)
                AppWell(
                  child: Text(
                    'Akun ini diarsipkan. Akun arsip tidak dihitung di net '
                    'worth dan alokasi, tetapi transaksinya tetap tersimpan.',
                    style: MyOSText.dataSm.copyWith(fontSize: 10, height: 14 / 10),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Says what the field is for, and names the one case where it starts empty
  /// instead of holding the current figure.
  String _balanceHelper(Account account) {
    final base = account.isLiability
        ? 'Nominal utang yang sebenarnya ada. Kosongkan kalau sudah benar.'
        : 'Nominal yang sebenarnya ada di akun ini. Kosongkan kalau sudah '
            'benar.';
    if (account.balance >= 0) return base;
    return '$base Saldo sekarang negatif, jadi field ini dibiarkan kosong.';
  }

  bool _validate() {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Nama akun wajib diisi' : null;
      final amount = Fmt.parseAmount(_initialBalance.text);
      _balanceError = !widget.isEditing && _initialBalance.text.isNotEmpty &&
              amount == null
          ? 'Nominal tidak valid'
          : null;
    });
    return _nameError == null && _balanceError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    final actions = ref.read(financeActionsProvider);
    final saved = await runGuarded(context, () async {
      if (widget.isEditing) {
        await actions.updateAccount(
          id: widget.accountId!,
          name: _name.text,
          type: _type,
          notes: _notes.text,
          isLiability: _isLiability,
          // An empty field means the balance was not corrected, so the ledger
          // is left alone instead of the form guessing a number.
          balance: Fmt.parseAmount(_initialBalance.text),
        );
      } else {
        await actions.createAccount(
          name: _name.text,
          type: _type,
          initialBalance: Fmt.parseAmount(_initialBalance.text) ?? 0,
          notes: _notes.text,
          isLiability: _isLiability,
        );
      }
    }, successMessage: widget.isEditing ? 'Akun diperbarui' : 'Akun disimpan');
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) context.pop();
  }

  Future<void> _toggleArchive() async {
    final data = ref.read(accountProvider(widget.accountId!)).value;
    if (data == null) return;
    final archived = !data.isArchived;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref
          .read(financeActionsProvider)
          .setAccountArchived(widget.accountId!, archived),
      successMessage: archived ? 'Akun diarsipkan' : 'Akun dipulihkan',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && !archived) setState(() {});
  }

  Future<void> _delete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Hapus akun?',
      message:
          'Akun hanya bisa dihapus kalau tidak punya transaksi. Kalau masih '
          'ada, arsipkan saja agar riwayatnya tetap utuh.',
      confirmLabel: 'Hapus akun',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ref.read(financeActionsProvider).deleteAccount(widget.accountId!),
      successMessage: 'Akun dihapus',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.pop();
  }
}
