import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/logic/live_market_data_service.dart';

void main() {
  final assets = InitialAssets.getAssets();
  final btc = assets.firstWhere((a) => a.symbol == 'BTC');
  final eth = assets.firstWhere((a) => a.symbol == 'ETH');
  final sol = assets.firstWhere((a) => a.symbol == 'SOL');

  String chart(
    String currency, {
    String stamps = '[10,20,30]',
    String closes = '[1.0,null,2.0]',
  }) =>
      '{"chart":{"result":[{"meta":{"currency":"$currency"},'
      '"timestamp":$stamps,'
      '"indicators":{"quote":[{"close":$closes}]}}]}}';

  Future<List<double>?> fetchWith(int status, dynamic asset, [String? body]) =>
      http.runWithClient(
        () => LiveMarketDataService().fetchHistoricalSeries(asset, '1M'),
        () => MockClient((_) async => http.Response(body ?? '{}', status)),
      );

  test(
    'a chart in an unsupported currency marks the history as permanently unavailable',
    () async {
      expect(LiveMarketDataService.historyUnavailable(btc), isFalse);
      expect(await fetchWith(200, btc, chart('CHF')), isNull);
      expect(LiveMarketDataService.historyUnavailable(btc), isTrue);
    },
  );

  test('a EUR chart returns its closes without gaps', () async {
    expect(await fetchWith(200, sol, chart('EUR')), [1.0, 2.0]);
  });

  test(
    'USD history is converted with the rate valid at each timestamp',
    () async {
      final stock = assets.firstWhere((a) => a.symbol == 'NVDA');
      // Prices 100/110/120 at t=10/20/30; EUR/USD 2.0 until t=20, then 4.0.
      final usd = chart('USD', closes: '[100.0,110.0,120.0]');
      final fx = chart('USD', stamps: '[5,25]', closes: '[2.0,4.0]');
      final series = await http.runWithClient(
        () => LiveMarketDataService().fetchHistoricalSeries(stock, '1M'),
        () => MockClient(
          (req) async =>
              http.Response(req.url.path.contains('EURUSD') ? fx : usd, 200),
        ),
      );
      expect(series, [50.0, 55.0, 30.0]);
    },
  );

  test('a temporary failure (503) does not', () async {
    expect(await fetchWith(503, eth), isNull);
    expect(LiveMarketDataService.historyUnavailable(eth), isFalse);
  });

  test('instruments without a live source are unavailable by design', () {
    final bond = assets.firstWhere((a) => a.type.name == 'bond');
    expect(LiveMarketDataService.historyUnavailable(bond), isTrue);
  });
}
