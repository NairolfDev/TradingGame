import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/app_theme.dart';
import 'data/repositories/trading_repository.dart';
import 'data/repositories/firebase_trading_repository.dart';
import 'logic/auth_provider.dart';
import 'logic/portfolio_provider.dart';
import 'firebase_options.dart';
import 'ui/screens/main_screen.dart';
import 'ui/screens/profile_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Graceful offline fallback
  }

  runApp(const TradingGameApp());
}

class TradingGameApp extends StatelessWidget {
  final TradingRepository? repository;

  const TradingGameApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, PortfolioProvider>(
          create: (_) => PortfolioProvider(
            repository: repository ?? FirebaseTradingRepository(),
          ),
          update: (_, auth, portfolio) =>
              portfolio!..updatePlayerProfile(auth.currentUser),
        ),
      ],
      child: MaterialApp(
        title: 'Trading Game – Börsenspiel Österreich',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Consumer<AuthProvider>(
          builder: (_, auth, _) {
            if (auth.isLoading) {
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
    );
  }
}
