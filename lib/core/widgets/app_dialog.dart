import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// Confirmation before a destructive action. Returns true only when the person
/// confirms, so a single stray tap never deletes a ledger row.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: MyOSColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MyOSRadius.lg),
        side: const BorderSide(color: MyOSColors.border),
      ),
      title: Text(title, style: MyOSText.cardTitle),
      content: Text(
        message,
        style: MyOSText.bodySm.copyWith(height: 18 / 12),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Batal',
            style: MyOSText.labelMd.copyWith(color: MyOSColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: MyOSText.labelMd.copyWith(color: MyOSColors.negative),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Feedback after a write. Errors are stated in the repository's own words, so
/// nothing technical reaches the screen.
void showFeedback(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: MyOSText.bodySm.copyWith(color: MyOSColors.textPrimary),
      ),
      backgroundColor: isError ? MyOSColors.surfaceHighest : MyOSColors.surface,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        side: BorderSide(
          color: isError
              ? MyOSColors.negative.withValues(alpha: 0.4)
              : MyOSColors.border,
        ),
      ),
      duration: Duration(seconds: isError ? 5 : 2),
    ),
  );
}

/// Action inside an informational panel. One implementation for empty states,
/// error panels and detail panels, so they cannot drift apart visually.
class PanelActionButton extends StatelessWidget {
  const PanelActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = PanelActionTone.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final PanelActionTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      PanelActionTone.accent => MyOSColors.accentDim,
      PanelActionTone.critical => MyOSColors.negative,
    };
    return Material(
      color: MyOSColors.surfaceHigh,
      borderRadius: BorderRadius.circular(MyOSRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyOSRadius.md),
            border: Border.all(color: MyOSColors.border),
          ),
          child: Text(label, style: MyOSText.labelMd.copyWith(color: color)),
        ),
      ),
    );
  }
}

enum PanelActionTone { accent, critical }

/// Full page failure state with a real recovery action, used when a screen
/// cannot load its data at all.
class AppErrorPanel extends StatelessWidget {
  const AppErrorPanel({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MyOSSpace.lg),
      decoration: BoxDecoration(
        color: MyOSColors.surface,
        borderRadius: BorderRadius.circular(MyOSRadius.lg),
        border: Border.all(color: MyOSColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GAGAL MEMUAT DATA',
            style: MyOSText.labelSm.copyWith(color: MyOSColors.negative),
          ),
          const SizedBox(height: MyOSSpace.sm),
          Text(
            message,
            style: MyOSText.bodySm.copyWith(height: 18 / 12),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: MyOSSpace.md),
            PanelActionButton(label: retryLabel, onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}

/// Route that no longer exists, for example a goal that was deleted while its
/// detail screen was open.
class NotFoundPanel extends StatelessWidget {
  const NotFoundPanel({super.key, required this.what, this.onBack});

  final String what;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MyOSSpace.lg),
      decoration: BoxDecoration(
        color: MyOSColors.surface,
        borderRadius: BorderRadius.circular(MyOSRadius.lg),
        border: Border.all(color: MyOSColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TIDAK DITEMUKAN', style: MyOSText.labelSm),
          const SizedBox(height: MyOSSpace.sm),
          Text(
            '$what sudah tidak ada. Mungkin baru saja dihapus dari layar '
            'sebelumnya.',
            style: MyOSText.bodySm.copyWith(height: 18 / 12),
          ),
          if (onBack != null) ...[
            const SizedBox(height: MyOSSpace.md),
            PanelActionButton(label: 'Kembali', onPressed: onBack),
          ],
        ],
      ),
    );
  }
}
