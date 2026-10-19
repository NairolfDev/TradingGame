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

  String chart(String currency) =>
      '{"chart":{"result":[{"meta":{"currency":"$currency"},'
      '"indicators":{"quote":[{"close":[1.0,null,2.0]}]}}]}}';

  Future<List<double>?> fetchWith(int status, dynamic asset, [String? body]) =>
      http.runWithClient(
        () => LiveMarketDataService().fetchHistoricalSeries(asset, '1M'),
        () => MockClient((_) async => http.Response(body ?? '{}', status)),
      );

  test(
    'a non-EUR chart marks the history as permanently unavailable',
    () async {
      expect(LiveMarketDataService.historyUnavailable(btc), isFalse);
      expect(await fetchWith(200, btc, chart('USD')), isNull);
      expect(LiveMarketDataService.historyUnavailable(btc), isTrue);
    },
  );

  test('a EUR chart returns its closes without gaps', () async {
    expect(await fetchWith(200, sol, chart('EUR')), [1.0, 2.0]);
  });

  test('a temporary failure (503) does not', () async {
    expect(await fetchWith(503, eth), isNull);
    expect(LiveMarketDataService.historyUnavailable(eth), isFalse);
  });

  test('instruments without a live source are unavailable by design', () {
    final bond = assets.firstWhere((a) => a.type.name == 'bond');
    expect(LiveMarketDataService.historyUnavailable(bond), isTrue);
  });
}
