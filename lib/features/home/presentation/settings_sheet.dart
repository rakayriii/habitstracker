import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/widgets/app_detail_scaffold.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/forms.dart';
import '../../../data/database/data_providers.dart';
import '../../../data/repositories/settings_repository.dart';
import '../providers/home_providers.dart';

/// Settings, opened from the avatar in the header.
///
/// It owns the two values the app actually keeps as settings: the operator name
/// used in the greeting, and the default currency applied to new accounts. No
/// other screen writes them, so there is no second copy to fall out of sync.
Future<void> showSettingsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MyOSColors.surfaceHigh,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(MyOSRadius.lg)),
    ),
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _name = TextEditingController();
  final _currency = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings != null && !_loaded) {
      _loaded = true;
      _name.text = settings[SettingsRepository.operatorNameKey] ?? '';
      _currency.text = settings[SettingsRepository.defaultCurrencyKey] ?? 'IDR';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: MyOSSpace.margin,
        right: MyOSSpace.margin,
        top: MyOSSpace.lg,
        bottom: MyOSSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Pengaturan', style: MyOSText.headlineSm),
                const Spacer(),
                HeaderTextAction(label: 'Tutup', onPressed: _close),
              ],
            ),
            const SizedBox(height: MyOSSpace.md),
            AppTextField(
              label: 'Nama operator',
              controller: _name,
              required: true,
              hint: 'mis. Raka',
              error: _nameError,
              helper: 'Dipakai untuk sapaan di Home dan inisial avatar',
              onChanged: (_) => setState(() => _nameError = null),
            ),
            const SizedBox(height: MyOSSpace.md),
            AppTextField(
              label: 'Mata uang default',
              controller: _currency,
              required: true,
              helper: 'Dipakai saat membuat akun baru',
            ),
            const SizedBox(height: MyOSSpace.lg),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Simpan pengaturan',
                    busy: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MyOSSpace.sm),
            Text(
              'Data tersimpan di perangkat ini. Tidak ada akun, tidak ada '
              'sinkronisasi cloud, tidak ada yang dikirim keluar.',
              style: MyOSText.dataSm.copyWith(fontSize: 10, height: 14 / 10),
            ),
          ],
        ),
      ),
    );
  }

  void _close() => Navigator.of(context).pop();

  Future<void> _save() async {
    final name = _name.text.trim();
    final currency = _currency.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nama operator wajib diisi');
      return;
    }
    if (currency.isEmpty) {
      showFeedback(context, 'Mata uang default wajib diisi', isError: true);
      return;
    }
    setState(() => _busy = true);
    final actions = ref.read(settingsActionsProvider);
    final ok = await runGuarded(context, () async {
      await actions.setOperatorName(name);
      await actions.setDefaultCurrency(currency.toUpperCase());
    }, successMessage: 'Pengaturan disimpan');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _close();
  }
}
