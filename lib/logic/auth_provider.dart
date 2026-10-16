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
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((fbUser) {
        if (fbUser != null) {
          if (_currentUser == null || _currentUser!.uid != fbUser.uid) {
            _currentUser = UserModel(
              uid: fbUser.uid,
              email: fbUser.email ?? 'trader@tradinggame.at',
              displayName: fbUser.displayName ??
                  (fbUser.email?.isNotEmpty == true
                      ? fbUser.email!.split('@').first
                      : 'Trader ${fbUser.uid.substring(0, 5)}'),
              photoUrl: fbUser.photoURL,
              authProvider: fbUser.isAnonymous ? 'guest' : 'firebase',
              isGuest: fbUser.isAnonymous,
            );
            notifyListeners();
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _loadUserSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check Web Redirect result (falls Google Redirect genutzt wurde)
      if (kIsWeb) {
        try {
          final redirectResult = await FirebaseAuth.instance.getRedirectResult();
          if (redirectResult.user != null) {
            final u = redirectResult.user!;
            _currentUser = UserModel(
              uid: u.uid,
              email: u.email ?? 'trader@tradinggame.at',
              displayName: u.displayName ??
                  (u.email?.isNotEmpty == true
                      ? u.email!.split('@').first
                      : 'Google Trader'),
              photoUrl: u.photoURL,
              authProvider: 'google',
              isGuest: false,
            );
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
            _isLoading = false;
            notifyListeners();
            return;
          }
        } catch (e) {
          debugPrint('Check redirect result error: $e');
        }
      }

      // 2. Check lokale Sitzung
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUser);
      if (raw != null) {
        _currentUser = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }

      // 3. Check aktuellen Firebase Auth Nutzer
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        _currentUser = UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? (_currentUser?.email ?? 'trader@tradinggame.at'),
          displayName: fbUser.displayName ?? (_currentUser?.displayName ?? 'Trader'),
          photoUrl: fbUser.photoURL ?? _currentUser?.photoUrl,
          authProvider: fbUser.isAnonymous ? 'guest' : (_currentUser?.authProvider ?? 'firebase'),
          isGuest: fbUser.isAnonymous,
        );
      } else {
        // Starte echte anonyme Firebase-Sitzung, damit Firestore-Zugriff sofort autorisiert ist
        try {
          final anonCred = await FirebaseAuth.instance.signInAnonymously();
          final u = anonCred.user;
          if (u != null && _currentUser == null) {
            _currentUser = UserModel(
              uid: u.uid,
              email: 'gast_${u.uid.substring(0, 6)}@tradinggame.at',
              displayName: 'Trader ${u.uid.substring(0, 5)}',
              authProvider: 'guest',
              isGuest: true,
            );
            await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
          }
        } catch (anonErr) {
          debugPrint('Anonymous auth notice: $anonErr');
        }
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

  /// Google Login über Firebase & GoogleSignIn (Web, Android, Desktop)
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      UserModel? loggedInUser;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        try {
          final userCred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
          final u = userCred.user;
          if (u != null) {
            loggedInUser = UserModel(
              uid: u.uid,
              email: u.email ?? 'trader@tradinggame.at',
              displayName: u.displayName ??
                  (u.email?.isNotEmpty == true
                      ? u.email!.split('@').first
                      : 'Google Trader'),
              photoUrl: u.photoURL,
              authProvider: 'google',
              isGuest: false,
            );
          }
        } on FirebaseAuthException catch (e) {
          debugPrint('Google Web signInWithPopup error: ${e.code} -> ${e.message}');
          if (e.code == 'popup-blocked' || e.code == 'cancelled-popup-request') {
            await FirebaseAuth.instance.signInWithRedirect(googleProvider);
            return true;
          }
          if (e.code == 'popup-closed-by-user') {
            _isLoading = false;
            notifyListeners();
            return false;
          }
          _errorMessage = 'Google-Anmeldung fehlgeschlagen: ${e.message ?? e.code}';
          _isLoading = false;
          notifyListeners();
          return false;
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
        } else {
          // Auswahl abgebrochen
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      if (loggedInUser != null) {
        _currentUser = loggedInUser;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Kein Google-Account ausgewählt.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Google Login fehlgeschlagen: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gast-Modus
  Future<void> signInAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String uid = 'guest_${_uuid.v4().substring(0, 8)}';
    try {
      final anon = await FirebaseAuth.instance.signInAnonymously();
      if (anon.user != null) {
        uid = anon.user!.uid;
      }
    } catch (_) {}

    _currentUser = UserModel(
      uid: uid,
      email: 'gast_${uid.substring(0, 6)}@tradinggame.local',
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
