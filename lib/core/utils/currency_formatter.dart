import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _euroFormat = NumberFormat.currency(
    locale: 'de_AT',
    symbol: '€',
    decimalDigits: 2,
  );

  static final NumberFormat _compactEuroFormat = NumberFormat.compactCurrency(
    locale: 'de_AT',
    symbol: '€',
    decimalDigits: 1,
  );

  static String format(num value) {
    return _euroFormat.format(value);
  }

  /// A dash instead of a misleading "€ 0,00" when a value is missing.
  static String formatOrDash(num? value) =>
      value == null || !value.isFinite || value <= 0 ? '–' : format(value);

  static String formatPrice(num value) {
    if (value < 1) {
      return '${value.toStringAsFixed(4)} €';
    }
    return _euroFormat.format(value);
  }

  static String formatCompact(num value) {
    return _compactEuroFormat.format(value);
  }

  static String formatPercent(double value, {bool showSign = true}) {
    final formatted = '${(value * 100).toStringAsFixed(2)}%';
    if (showSign && value > 0) {
      return '+$formatted';
    }
    return formatted;
  }

  static String formatAmount(double value, {int maxDecimals = 4}) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(maxDecimals)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}
