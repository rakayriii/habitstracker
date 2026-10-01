import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/forms.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/ledger_row.dart';
import '../../../domain/models/focus_item.dart';
import '../providers/focus_providers.dart';

Color _priorityColor(FocusPriority priority) => switch (priority) {
  FocusPriority.p1 => MyOSColors.accent,
  FocusPriority.p2 => MyOSColors.textSecondary,
  FocusPriority.p3 => MyOSColors.textMuted,
};

/// Today's focus, read straight from the database for the current day. The
/// checkbox writes to the same table, so the counter in the header moves on the
/// next frame and survives a restart.
class FocusList extends ConsumerWidget {
  const FocusList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(todayFocusProvider);
    final actions = ref.read(focusActionsProvider);

    return AsyncContent<List<FocusItem>>(
      value: items,
      onRetry: () => ref.invalidate(todayFocusProvider),
      builder: (rows) {
        if (rows.isEmpty) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HARI INI KOSONG', style: MyOSText.labelSm),
                const SizedBox(height: MyOSSpace.sm),
                Text(
                  'Belum ada yang direncanakan hari ini. Tambahkan satu item '
                  'yang benar-benar penting, sisanya bisa menunggu.',
                  style: MyOSText.bodySm.copyWith(height: 18 / 12),
                ),
                const SizedBox(height: MyOSSpace.md),
                PanelActionButton(
                  label: 'Tambah fokus',
                  onPressed: () => context.push('/focus/new'),
                ),
              ],
            ),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.md),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                LedgerRow(
                  title: rows[i].title,
                  subtitle: rows[i].notes == null || rows[i].notes!.isEmpty
                      ? rows[i].priority.hint
                      : rows[i].notes!,
                  value: rows[i].priority.label,
                  valueColor: rows[i].isCompleted
                      ? MyOSColors.textMuted
                      : _priorityColor(rows[i].priority),
                  titleStyle: rows[i].isCompleted
                      ? MyOSText.bodyMd.copyWith(
                          fontSize: 13,
                          color: MyOSColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: MyOSColors.textDisabled,
                        )
                      : null,
                  divider: i < rows.length - 1,
                  onTap: () => context.push('/focus/${rows[i].id}'),
                  leading: AppCheckboxLike(
                    checked: rows[i].isCompleted,
                    semanticLabel: rows[i].title,
                    onChanged: (value) => runGuarded(
                      context,
                      () => actions.setCompleted(rows[i].id, value),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
