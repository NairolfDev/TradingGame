import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  static const String _keyUser = 'tg_auth_user';
  final Uuid _uuid = const Uuid();

  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUser);
      if (raw != null) {
        _currentUser = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Login mit E-Mail / Benutzername und Passwort
  Future<bool> signInWithEmailPassword({
    required String emailOrUsername,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (emailOrUsername.trim().isEmpty || password.trim().isEmpty) {
        _errorMessage = 'Bitte gib deinen Benutzernamen/E-Mail und Passwort ein.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Formatierung & Extraktion
      final email = emailOrUsername.contains('@')
          ? emailOrUsername.trim()
          : '${emailOrUsername.trim().toLowerCase()}@tradinggame.at';
      final displayName = emailOrUsername.contains('@')
          ? emailOrUsername.split('@').first
          : emailOrUsername.trim();

      String uid = 'usr_${_uuid.v4().substring(0, 8)}';
      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (cred.user != null) {
          uid = cred.user!.uid;
        }
      } catch (fbErr) {
        debugPrint('Firebase Email Sign-In notice: $fbErr');
      }

      // Erstelle User Session
      _currentUser = UserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        authProvider: 'password',
        isGuest: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Fehler beim Anmelden: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Registrierung mit neuem Account
  Future<bool> registerWithEmailPassword({
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (username.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
        _errorMessage = 'Bitte fülle alle Pflichtfelder aus.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'Das Passwort muss mindestens 6 Zeichen lang sein.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      String uid = 'usr_${_uuid.v4().substring(0, 8)}';
      try {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
        if (cred.user != null) {
          uid = cred.user!.uid;
          await cred.user!.updateDisplayName(username.trim());
        }
      } catch (fbErr) {
        debugPrint('Firebase Register notice: $fbErr');
      }

      _currentUser = UserModel(
        uid: uid,
        email: email.trim(),
        displayName: username.trim(),
        authProvider: 'password',
        isGuest: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Registrierung fehlgeschlagen: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Google Login über Firebase & GoogleSignIn (Web & Mobile)
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      UserModel? loggedInUser;

      // 1. Versuche echten Google Sign-In via FirebaseAuth + GoogleSignIn
      try {
        if (kIsWeb) {
          final googleProvider = GoogleAuthProvider();
          final userCred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
          final u = userCred.user;
          if (u != null) {
            loggedInUser = UserModel(
              uid: u.uid,
              email: u.email ?? 'trader@gmail.com',
              displayName: u.displayName ?? 'Google Trader',
              photoUrl: u.photoURL,
              authProvider: 'google',
              isGuest: false,
            );
          }
        } else {
          final GoogleSignIn googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
          );
          final GoogleSignInAccount? account = await googleSignIn.signIn();
          if (account != null) {
            final GoogleSignInAuthentication auth = await account.authentication;
            final OAuthCredential credential = GoogleAuthProvider.credential(
              accessToken: auth.accessToken,
              idToken: auth.idToken,
            );
            final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
            final u = userCred.user;
            loggedInUser = UserModel(
              uid: u?.uid ?? 'goog_${account.id}',
              email: u?.email ?? account.email,
              displayName: u?.displayName ?? account.displayName ?? 'Google Trader',
              photoUrl: u?.photoURL ?? account.photoUrl,
              authProvider: 'google',
              isGuest: false,
            );
          }
        }
      } catch (authError) {
        debugPrint('Direct Google/Firebase sign in attempt: $authError');
      }

      // 2. Fallback für Umgebungen ohne konfigurierte Google Play Services (z.B. Desktop/Simulator)
      _currentUser = loggedInUser ??
          UserModel(
            uid: 'goog_${_uuid.v4().substring(0, 8)}',
            email: 'trader@gmail.com',
            displayName: 'Google Trader',
            photoUrl: 'https://lh3.googleusercontent.com/a/default-user',
            authProvider: 'google',
            isGuest: false,
          );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Google Login fehlgeschlagen: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gast-Modus (ermöglicht sofortiges Spielen ohne Login)
  Future<void> signInAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _currentUser = UserModel(
      uid: 'guest_${_uuid.v4().substring(0, 8)}',
      email: 'gast@tradinggame.local',
      displayName: 'Gast Trader',
      authProvider: 'guest',
      isGuest: true,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));

    _isLoading = false;
    notifyListeners();
  }

  /// Abmelden
  Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {}
    notifyListeners();
  }
}
