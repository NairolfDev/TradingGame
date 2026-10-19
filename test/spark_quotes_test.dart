import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/logic/live_market_data_service.dart';

String entry(String symbol, String currency, double price) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return '{"symbol":"$symbol","response":[{"meta":{"currency":"$currency",'
      '"regularMarketPrice":$price,"regularMarketTime":$now,'
      '"chartPreviousClose":${price * 0.9}},'
      '"timestamp":[${now - 60},$now],'
      '"indicators":{"quote":[{"close":[${price * 0.95},$price]}]}}]}';
}

void main() {
  test('one spark request prices EUR and USD stocks', () async {
    final assets = InitialAssets.getAssets();
    final ebs = assets.firstWhere((a) => a.symbol == 'EBS.VI');
    final nvda = assets.firstWhere((a) => a.symbol == 'NVDA');
    var calls = 0;
    final quotes = await http.runWithClient(
      () => LiveMarketDataService().refreshQuotesForAssets([ebs, nvda]),
      () => MockClient((req) async {
        calls++;
        expect(req.url.path, endsWith('/spark'));
        return http.Response(
          '{"spark":{"result":[${entry('EURUSD=X', 'USD', 2.0)},'
          '${entry('EURJPY=X', 'JPY', 160)},'
          '${entry('EBS.VI', 'EUR', 50)},${entry('NVDA', 'USD', 200)}]}}',
          200,
        );
      }),
    );
    expect(calls, 1);
    expect(quotes['EBS.VI']?.currentPrice, 50);
    expect(quotes['NVDA']?.currentPrice, closeTo(100, 1e-9));
  });

  test('instruments without a source sector take it from the category', () {
    final ebs = InitialAssets.getAssets().firstWhere(
      (a) => a.symbol == 'EBS.VI',
    );
    expect(ebs.sector, 'Finanzen');
    final cfd = InitialAssets.getAssets().firstWhere(
      (a) => a.type == AssetType.cfd,
    );
    expect(cfd.sector, isNot('Unbekannt'));
  });
}
