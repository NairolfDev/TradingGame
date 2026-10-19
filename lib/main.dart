import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/app_theme.dart';
import 'data/repositories/trading_repository.dart';
import 'data/repositories/firebase_trading_repository.dart';
import 'logic/auth_provider.dart';
import 'logic/notification_service.dart';
import 'logic/portfolio_provider.dart';
import 'logic/price_alerts_controller.dart';
import 'logic/version_gate.dart';
import 'logic/theme_controller.dart';
import 'firebase_options.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/profile_setup_screen.dart';
import 'ui/widgets/notification_host.dart';
import 'ui/widgets/reward_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: _firebaseOptions());
  } catch (e) {
    // Graceful offline fallback; log so a broken config is visible.
    debugPrint('Firebase init failed: $e');
  }

  runApp(const TradingGameApp());
}

/// On Firebase Hosting the auth handler (/__/auth/*) is served from the app's
/// own domain. Using it as authDomain keeps the Google popup first-party;
/// with firebaseapp.com, Chrome's third-party storage partitioning drops the
/// popup result and sign-in hangs after choosing the account.
FirebaseOptions _firebaseOptions() {
  final host = Uri.base.host;
  if (kIsWeb && host != 'localhost' && host != '127.0.0.1' && host.isNotEmpty) {
    return DefaultFirebaseOptions.web.copyWith(authDomain: host);
  }
  return DefaultFirebaseOptions.currentPlatform;
}

class TradingGameApp extends StatefulWidget {
  final TradingRepository? repository;

  const TradingGameApp({super.key, this.repository});

  @override
  State<TradingGameApp> createState() => _TradingGameAppState();
}

class _TradingGameAppState extends State<TradingGameApp> {
  final _theme = ThemeController();

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _theme),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => PriceAlertsController()),
        ChangeNotifierProvider(create: (_) => AuthProvider(sessionStamp: const SessionStamp())),
        ChangeNotifierProxyProvider<AuthProvider, PortfolioProvider>(
          create: (_) => PortfolioProvider(
            repository: repository ?? FirebaseTradingRepository(),
          ),
          update: (_, auth, portfolio) =>
              portfolio!..updatePlayerProfile(auth.currentUser),
        ),
      ],
      child: PaletteRebuilder(
        controller: _theme,
        child: Consumer<ThemeController>(
          builder: (_, _, _) => MaterialApp(
            title: 'Trading Game – Börsenspiel Österreich',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.current,
            builder: (_, child) =>
                NotificationHost(child: RewardOverlay(child: child!)),
            home: Consumer<AuthProvider>(
              builder: (_, auth, _) {
                if (auth.isInitializing) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return auth.needsProfile
                    ? const ProfileSetupScreen()
                    : const MainScreen();
              },
            ),
          ),
        ),
      ),
    );
  }
}
