import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';

import '../../../data/database/data_providers.dart';

/// Home is an aggregation layer and nothing else.
///
/// Every number it shows is read from the module that owns it: net worth from
/// the finance summary, goals from the goals list, projects from the projects
/// list, focus from today's focus. There is no Home table and no Home copy of
/// any record, which is why a transaction added in Finance moves the number
/// here without Home knowing that Finance changed.
///
/// Re-exported so the Home screen has one import for its inputs.
export '../../finance/providers/finance_providers.dart' show financeSummaryProvider;
export '../../focus/providers/focus_providers.dart'
    show focusCountsProvider, nextFocusProvider, overdueFocusProvider, todayFocusProvider;
export '../../goals/providers/goal_providers.dart'
    show goalCompletionProvider, homeGoalsProvider, onTrackCountProvider;
export '../../projects/providers/project_providers.dart'
    show homeProjectsProvider, openTaskCountProvider;

/// Header greeting, built from the stored operator name and the current hour.
final operatorNameProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider).value;
  final name = settings?[SettingsRepository.operatorNameKey]?.trim();
  return (name == null || name.isEmpty) ? 'Operator' : name;
});

/// Avatar initial, derived from the same setting. No photo is invented.
final operatorInitialProvider = Provider<String>((ref) {
  final name = ref.watch(operatorNameProvider);
  if (name.isEmpty) return '?';
  // First code unit is enough for an initial mask; names are stored as typed
  // and an emoji initial would look like a bug in a 32px circle.
  return name.substring(0, 1).toUpperCase();
});

/// Writes for the settings sheet opened from the header.
class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  Future<void> setOperatorName(String value) {
    return _ref
        .read(settingsRepositoryProvider)
        .write(SettingsRepository.operatorNameKey, value.trim());
  }

  Future<void> setDefaultCurrency(String value) {
    return _ref
        .read(settingsRepositoryProvider)
        .write(SettingsRepository.defaultCurrencyKey, value.trim());
  }
}

final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);
