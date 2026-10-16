import 'package:flutter_test/flutter_test.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/logic/live_market_data_service.dart';

void main() {
  final assets = InitialAssets.getAssets();
  test(
    'existing EUR stocks and ETFs resolve without explicit Yahoo metadata',
    () {
      for (final symbol in ['OMV.VI', 'SAP.DE', 'ASML.AS']) {
        expect(
          LiveMarketDataService.euroYahooSymbolFor(
            assets.firstWhere((a) => a.symbol == symbol),
          ),
          symbol,
        );
      }
      expect(
        LiveMarketDataService.euroYahooSymbolFor(
          assets.firstWhere((a) => a.symbol == 'EUNL'),
        ),
        'EUNL.DE',
      );
    },
  );
  test(
    'crypto history uses the EUR pair and USD futures are not relabeled EUR',
    () {
      expect(
        LiveMarketDataService.euroYahooSymbolFor(
          assets.firstWhere((a) => a.symbol == 'BTC'),
        ),
        'BTC-EUR',
      );
      expect(
        LiveMarketDataService.euroYahooSymbolFor(
          assets.firstWhere((a) => a.symbol == 'XAU/EUR'),
        ),
        isNull,
      );
      expect(
        LiveMarketDataService.euroYahooSymbolFor(
          assets.firstWhere((a) => a.symbol == 'NVDA'),
        ),
        isNull,
      );
    },
  );
}
