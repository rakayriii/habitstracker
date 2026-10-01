import 'dart:math';

/// Stable, human readable row identifiers.
///
/// The prefix keeps a raw id legible in a database browser, and the random
/// suffix keeps it unique across installs. Ids are never derived from row
/// order, so a row can be exported and re-imported without renumbering.
class IdGen {
  IdGen._();

  static final _random = Random();

  static String next(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _random.nextInt(1 << 32).toRadixString(36).padLeft(6, '0');
    return '$prefix-$now$salt';
  }
}
