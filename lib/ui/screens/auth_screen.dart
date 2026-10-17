import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback? onAuthenticated;
  const AuthScreen({super.key, this.onAuthenticated});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _success() {
    if (!mounted) return;
    if (widget.onAuthenticated != null) {
      widget.onAuthenticated!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Trading Game')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.candlestick_chart, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _register ? 'Konto erstellen' : 'Willkommen zurück',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Melde dich an, um dein Portfolio zu speichern.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      enabled: !auth.isLoading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-Mail-Adresse',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      enabled: !auth.isLoading,
                      obscureText: _obscure,
                      autofillHints: [
                        _register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: _register
                            ? 'Passwort (mindestens 6 Zeichen)'
                            : 'Passwort',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Passwort anzeigen'
                              : 'Passwort verbergen',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        auth.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              final success = _register
                                  ? await auth.registerWithEmailPassword(
                                      email: _email.text,
                                      password: _password.text,
                                    )
                                  : await auth.signInWithEmailPassword(
                                      emailOrUsername: _email.text,
                                      password: _password.text,
                                    );
                              if (success) _success();
                            },
                      child: Text(
                        auth.isLoading
                            ? 'Bitte warten …'
                            : (_register ? 'Konto erstellen' : 'Anmelden'),
                      ),
                    ),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              auth.clearError();
                              setState(() => _register = !_register);
                            },
                      child: Text(
                        _register
                            ? 'Schon ein Konto? Anmelden'
                            : 'Neues Konto erstellen',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    OutlinedButton.icon(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              if (await auth.signInWithGoogle()) _success();
                            },
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('Mit Google anmelden'),
                    ),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              await auth.signInAsGuest();
                              if (auth.currentUser != null) _success();
                            },
                      child: const Text('Als Gast spielen'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
