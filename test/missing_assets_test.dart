import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/mock_data/initial_assets.dart';
import 'package:trading_game/data/models/asset.dart';
import 'package:trading_game/data/repositories/local_trading_repository.dart';
import 'package:trading_game/logic/live_market_data_service.dart';

void main() {
  test('instruments added after a list was saved still appear', () async {
    final old = InitialAssets.getAssets()
        .where((a) => a.type != AssetType.commodity)
        .toList();
    SharedPreferences.setMockInitialValues({
      'tg_assets': jsonEncode(old.map((a) => a.toJson()).toList()),
    });
    final loaded = await LocalTradingRepository().getAssets();
    expect(loaded.any((a) => a.id == 'com_gold'), isTrue);
    expect(
      loaded.where((a) => a.id == 'com_gold').length,
      1,
      reason: 'no duplicates',
    );
  });

  test('gold has a live source (USD future converted to EUR)', () {
    final gold = InitialAssets.getAssets().firstWhere(
      (a) => a.id == 'com_gold',
    );
    expect(LiveMarketDataService.euroYahooSymbolFor(gold), 'GC=F');
  });
}
