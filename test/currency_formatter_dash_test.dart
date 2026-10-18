import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/core/utils/currency_formatter.dart';

void main() {
  test('missing, non-finite and non-positive values show a dash', () {
    for (final v in <num?>[null, 0, -1, double.nan, double.infinity]) {
      expect(CurrencyFormatter.formatOrDash(v), '–', reason: '$v');
    }
  });

  test('real values are formatted like format()', () {
    expect(
      CurrencyFormatter.formatOrDash(2.45),
      CurrencyFormatter.format(2.45),
    );
  });
}
