import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/logic/market_filter_views.dart';

void main() {
  test('named filters round trip and deletion survives a new store', () async {
    SharedPreferences.setMockInitialValues({});
    final view = <String, dynamic>{
      'query': 'Erste',
      'groups': ['ATX'],
      'watchlist': true,
      'sector': 'Finanzen',
      'sort': 'priceAsc',
    };
    await MarketFilterViews().save({'Meine Banken': view});
    expect(await MarketFilterViews().load(), {'Meine Banken': view});
    await MarketFilterViews().save({});
    expect(await MarketFilterViews().load(), isEmpty);
  });
  test('invalid persisted JSON and non-view entries recover safely', () async {
    SharedPreferences.setMockInitialValues({
      MarketFilterViews.storageKey: '{broken',
    });
    expect(await MarketFilterViews().load(), isEmpty);
    SharedPreferences.setMockInitialValues({
      MarketFilterViews.storageKey: '{"wrong":7,"valid":{"groups":["DAX"]}}',
    });
    expect((await MarketFilterViews().load()).keys, ['valid']);
  });
}
