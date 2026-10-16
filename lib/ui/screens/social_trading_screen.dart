import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SocialTradingScreen extends StatelessWidget {
  const SocialTradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Social- & Copy-Trading')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 56, color: AppColors.accent),
                SizedBox(height: 24),
                Text(
                  'Noch keine öffentlichen Portfolios',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Aktuell ist kein verifizierter Portfolio-Feed angebunden. '
                  'Sobald echte Portfolios verfügbar sind, erscheinen sie hier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
