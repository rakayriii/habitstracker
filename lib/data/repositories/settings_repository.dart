
import '../database/app_database.dart';

/// Application settings: a small key/value table the UI actually reads.
///
/// Today it owns the operator name shown in the Home header and the default
/// currency applied to new accounts. Nothing else writes to it, so there is no
/// second place where this state could live.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const operatorNameKey = 'operatorName';
  static const defaultCurrencyKey = 'defaultCurrency';

  Stream<Map<String, String>> watchAll() {
    return _db.select(_db.settings).watch().map(
          (rows) => {for (final row in rows) row.key: row.value},
        );
  }

  Future<String?> read(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((setting) => setting.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) async {
    final now = DateTime.now();
    await _db.into(_db.settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value, updatedAt: now),
    );
  }

  /// The settings that the shell needs on first paint, so the header does not
  /// flash a default name while the stream warms up.
  Future<Map<String, String>> readAll() async {
    final rows = await _db.select(_db.settings).get();
    return {for (final row in rows) row.key: row.value};
  }
}

