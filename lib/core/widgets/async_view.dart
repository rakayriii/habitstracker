import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';
import '../widgets/app_detail_scaffold.dart';
import '../widgets/app_dialog.dart';
import '../../domain/errors.dart';

/// Turns any error into something a person can act on. Repository exceptions
/// already carry user facing text; anything else is reported generically so a
/// stack trace never reaches the screen.
String userMessage(Object error) {
  return switch (error) {
    AppException() => error.message,
    _ => 'Terjadi kesalahan. Coba lagi atau periksa data yang dimasukkan.',
  };
}

/// Loading, error and data, in that order.
///
/// A first load shows the quiet progress line rather than a spinner in the
/// middle of the screen, because the read is a local SQLite query and the
/// content area should keep its place.
class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
    this.skipLoadingOnRefresh = true,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  /// True while a background refresh runs, when the previous data is still
  /// worth showing.
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue && skipLoadingOnRefresh) {
      return builder(value.requireValue);
    }
    return value.when(
      data: builder,
      loading: () => loading ?? const LoadingLine(),
      error: (error, _) => AppErrorPanel(
        message: userMessage(error),
        onRetry: onRetry,
      ),
    );
  }
}

/// Runs a write and reports the outcome. Every form goes through this, so
/// failure always produces a message and success only navigates when the write
/// actually landed.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String? successMessage,
}) async {
  try {
    await action();
    if (successMessage != null && context.mounted) {
      showFeedback(context, successMessage);
    }
    return true;
  } on AppException catch (error) {
    if (context.mounted) showFeedback(context, error.message, isError: true);
    return false;
  } catch (_) {
    if (context.mounted) {
      showFeedback(
        context,
        'Perubahan tidak tersimpan. Coba lagi.',
        isError: true,
      );
    }
    return false;
  }
}

/// Inline error strip for a section that failed to load while the rest of the
/// screen is fine.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MyOSSpace.md),
      decoration: BoxDecoration(
        color: MyOSColors.surface,
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        border: Border.all(
          color: MyOSColors.negative.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: MyOSText.dataSm.copyWith(color: MyOSColors.negative),
            ),
          ),
          if (onRetry != null)
            HeaderTextAction(label: 'Coba lagi', onPressed: onRetry!),
        ],
      ),
    );
  }
}
