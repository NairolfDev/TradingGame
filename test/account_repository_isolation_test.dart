import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/data/repositories/firebase_trading_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account repositories keep asynchronous fallback writes isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = FirebaseTradingRepository(userId: 'alice');
      final second = FirebaseTradingRepository(userId: 'bob');
      final delayedSave = Future<void>.delayed(
        const Duration(milliseconds: 10),
        () => first.saveCashBalance(1234),
      );
      expect(await second.getCashBalance(), 50000);
      await second.saveCashBalance(5678);
      await delayedSave;
      expect(await first.getCashBalance(), 1234);
      expect(await second.getCashBalance(), 5678);
    },
  );
}
