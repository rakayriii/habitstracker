/// Number, money and date formatting for the ledger surfaces.
///
/// Hand-rolled rather than pulled from `intl`: the app needs Indonesian
/// rupiah grouping, Indonesian month names, a handful of relative day labels
/// and a strict money parser for form input. A locale package would be a
/// dependency for less than this file does.
class Fmt {
  const Fmt._();

  static const _monthsLong = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const _daysLong = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// `12450000` becomes `12.450.000`. Indonesian grouping uses a dot every
  /// three digits, so the columns stay readable at 11px in a dense row.
  static String group(int value) {
    final isNegative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return '${isNegative ? '-' : ''}$buffer';
  }

  static String _compact(int value) {
    if (value.abs() >= 1e12) return '${_trim(value / 1e12)} T';
    if (value.abs() >= 1e9) return '${_trim(value / 1e9)} M';
    if (value.abs() >= 1e6) return '${_trim(value / 1e6)} jt';
    if (value.abs() >= 1e3) return '${_trim(value / 1e3)} rb';
    return value.toString();
  }

  static String _trim(double value) {
    final rounded = (value * 10).roundToDouble() / 10;
    if (rounded == rounded.truncateToDouble()) {
      return rounded.truncate().toString();
    }
    return rounded.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// `Rp 12.450.000`, negative values render as `-Rp 850.000`.
  static String idr(num value) {
    final rounded = value.round();
    final prefix = rounded < 0 ? '-Rp ' : 'Rp ';
    return '$prefix${group(rounded.abs())}';
  }

  /// `Rp 12,45 jt` for cells where the exact rupiah value is noise.
  static String idrCompact(num value) {
    final rounded = value.round();
    final prefix = rounded < 0 ? '-Rp ' : 'Rp ';
    return '$prefix${_compact(rounded.abs())}';
  }

  static String signedIdr(num value) {
    if (value == 0) return idr(0);
    return '${value > 0 ? '+' : ''}${idr(value)}';
  }

  /// Parses user input into rupiah. Accepts `12500`, `12.500`, `12,500`,
  /// `12.500,50` and `Rp 12.500`. Returns null when the text is not a
  /// non-negative amount, so a form can reject it instead of storing junk.
  static int? parseAmount(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[^0-9,]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final value = int.tryParse(cleaned);
    if (value == null) return null;
    return value;
  }

  /// Regroups typed digits while the user types, so the field always shows a
  /// readable amount. Digits only: a partial number keeps its place.
  static String formatAmountInput(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return group(int.parse(trimmed));
  }

  static String percent(double ratio, {int decimals = 0}) {
    final value = ratio * 100;
    final text = decimals == 0
        ? value.round().toString()
        : value.toStringAsFixed(decimals).replaceAll('.', ',');
    return '$text%';
  }

  static String signedPercent(double ratio, {int decimals = 1}) {
    final value = ratio * 100;
    final text = value.toStringAsFixed(decimals).replaceAll('.', ',');
    return '${value >= 0 ? '+' : ''}$text%';
  }

  static String longDate(DateTime date) {
    return '${_daysLong[date.weekday - 1]}, ${date.day} '
        '${_monthsLong[date.month - 1]} ${date.year}';
  }

  static String shortDate(DateTime date) {
    return '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';
  }

  static String dayMonth(DateTime date) {
    return '${date.day} ${_monthsShort[date.month - 1]}';
  }

  static String monthLabel(DateTime date) => _monthsShort[date.month - 1];

  /// Day labels for the transaction ledger. Anything older falls back to a
  /// date so a stale ledger never shows a wrong "today".
  static String relativeDay(DateTime date, DateTime now) {
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    return switch (days) {
      0 => 'Hari ini',
      1 => 'Kemarin',
      < 7 => '$days hari lalu',
      _ => dayMonth(date),
    };
  }

  static String greeting(DateTime now) {
    if (now.hour < 11) return 'Selamat pagi';
    if (now.hour < 15) return 'Selamat siang';
    if (now.hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  static String clock(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
