import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/countries.dart';
import '../../logic/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  String? _country;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    'Dein Trader-Profil',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wähle deinen Namen und dein Land. Danach kannst du loslegen.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _name,
                    enabled: !auth.isProfileLoading,
                    maxLength: 24,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Anzeigename'),
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<String>(
                    expandedInsets: EdgeInsets.zero,
                    enabled: !auth.isProfileLoading,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    menuHeight: 300,
                    label: const Text('Land'),
                    onSelected: (value) => setState(() => _country = value),
                    dropdownMenuEntries: countryNames.entries
                        .map(
                          (country) => DropdownMenuEntry(
                            value: country.key,
                            label: country.value,
                          ),
                        )
                        .toList(),
                  ),
                  if (auth.profileError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.profileError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: auth.isProfileLoading
                          ? null
                          : auth.reloadProfile,
                      child: const Text('Gespeichertes Profil erneut laden'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.isProfileLoading || _country == null
                        ? null
                        : () => auth.completeProfile(
                            displayName: _name.text,
                            countryCode: _country!,
                          ),
                    child: Text(
                      auth.isProfileLoading
                          ? 'Profil wird gespeichert …'
                          : 'Loslegen',
                    ),
                  ),
                  TextButton(
                    onPressed: auth.isProfileLoading ? null : auth.signOut,
                    child: const Text('Abmelden'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
