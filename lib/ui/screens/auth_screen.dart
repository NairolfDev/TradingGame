import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../logic/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;

  const AuthScreen({super.key, this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login Controller
  final TextEditingController _loginIdentifierController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Register Controller
  final TextEditingController _regUsernameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();

  bool _obscurePassword = true;

  void _onSuccess() {
    if (widget.onAuthenticated != null) {
      widget.onAuthenticated!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Brand & Icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.candlestick_chart,
                      size: 38,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TRADING GAME',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Österreich Börsenspiel • 50.000 € Startkapital',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Fehlermeldung (falls vorhanden)
                  if (authProvider.errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.loss.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.loss.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 18, color: AppColors.loss),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authProvider.errorMessage!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.loss,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Card mit Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        // Tab Bar
                        TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 3,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          tabs: const [
                            Tab(text: 'Anmelden'),
                            Tab(text: 'Registrieren'),
                          ],
                        ),

                        // Formulare
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            height: 230,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Tab 1: Login
                                _buildLoginForm(authProvider),
                                // Tab 2: Register
                                _buildRegisterForm(authProvider),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Trennlinie "ODER"
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.cardBorder)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ODER',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.cardBorder)),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Google Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () async {
                        final success = await authProvider.signInWithGoogle();
                        if (success) _onSuccess();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🌐', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 10),
                          Text(
                            'Mit Google anmelden',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Gast-Modus Button (Sofort starten ohne Login)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () async {
                        await authProvider.signInAsGuest();
                        _onSuccess();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Als Gast fortfahren (Sofort ohne Login spielen)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider authProvider) {
    return Column(
      children: [
        TextField(
          controller: _loginIdentifierController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Benutzername oder E-Mail',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.person_outline,
                color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Passwort',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppColors.textMuted, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: () async {
              final success = await authProvider.signInWithEmailPassword(
                emailOrUsername: _loginIdentifierController.text,
                password: _loginPasswordController.text,
              );
              if (success) _onSuccess();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Anmelden',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthProvider authProvider) {
    return Column(
      children: [
        TextField(
          controller: _regUsernameController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Dein Trader-Name',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.badge_outlined,
                color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _regEmailController,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'E-Mail Adresse',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.email_outlined,
                color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _regPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Passwort (min. 6 Zeichen)',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () async {
              final success = await authProvider.registerWithEmailPassword(
                username: _regUsernameController.text,
                email: _regEmailController.text,
                password: _regPasswordController.text,
              );
              if (success) _onSuccess();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Account erstellen',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
