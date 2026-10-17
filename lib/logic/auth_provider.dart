import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/countries.dart';
import '../data/models/user_model.dart';
import '../data/repositories/player_profile_repository.dart';

class AuthProvider extends ChangeNotifier {
  static const _keyUser = 'tg_auth_user';
  final FirebaseAuth? _authOverride;
  final PlayerProfileRepository _profiles;
  StreamSubscription<User?>? _subscription;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _profileLoading = false;
  bool _profileLoaded = false;
  bool _disposed = false;
  int _sessionVersion = 0;
  String? _errorMessage;
  String? _profileError;

  AuthProvider({FirebaseAuth? firebaseAuth, PlayerProfileRepository? profiles})
    : _authOverride = firebaseAuth,
      _profiles = profiles ?? FirebasePlayerProfileRepository() {
    _initialize();
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && !_currentUser!.isGuest;
  bool get isLoading => _isLoading;
  bool get isProfileLoading => _profileLoading;
  String? get errorMessage => _errorMessage;
  String? get profileError => _profileError;
  bool get needsProfile =>
      isAuthenticated &&
      (!_profileLoaded ||
          _currentUser!.displayName.trim().runes.length < 2 ||
          !countryNames.containsKey(_currentUser!.countryCode));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _initialize() async {
    try {
      if (kIsWeb) {
        try {
          await _auth.getRedirectResult();
        } on FirebaseAuthException catch (e) {
          _errorMessage = _authError(e);
        }
      }
      final user = await _auth.authStateChanges().first;
      await _acceptUser(user);
      if (_disposed) return;
      _subscription = _auth.authStateChanges().listen(
        (user) {
          if (user?.uid != _currentUser?.uid ||
              (user == null && _currentUser != null)) {
            unawaited(_acceptUser(user));
          }
        },
        onError: (Object error) {
          _errorMessage =
              'Die Anmeldung konnte nicht wiederhergestellt werden. Bitte erneut anmelden.';
          _notify();
        },
      );
    } catch (_) {
      // Local guest mode is allowed; a local cache never proves a real login.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUser);
      try {
        final cached = raw == null
            ? null
            : UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (cached?.isGuest == true) _currentUser = cached;
      } catch (_) {}
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  UserModel _fromFirebase(User user, {String? name, String? countryCode}) {
    final shortId = user.uid.length > 6 ? user.uid.substring(0, 6) : user.uid;
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: name ?? user.displayName ?? 'Trader $shortId',
      photoUrl: user.photoURL,
      authProvider: user.isAnonymous
          ? 'guest'
          : (user.providerData.any((p) => p.providerId == 'google.com')
                ? 'google'
                : 'password'),
      isGuest: user.isAnonymous,
      countryCode: countryCode,
    );
  }

  Future<void> _acceptUser(User? user) async {
    final version = ++_sessionVersion;
    _profileError = null;
    _profileLoaded = false;
    _currentUser = user == null ? null : _fromFirebase(user);
    if (user == null || user.isAnonymous) {
      _profileLoading = false;
      _notify();
      return;
    }
    _profileLoading = true;
    _notify();
    try {
      final profile = await _profiles
          .load(user.uid)
          .timeout(const Duration(seconds: 15));
      if (_disposed || version != _sessionVersion) return;
      _currentUser = _fromFirebase(
        user,
        name: profile?['displayName'] as String?,
        countryCode: profile?['countryCode'] as String?,
      );
      final savedName = profile?['displayName'];
      _profileLoaded =
          savedName is String &&
          savedName.trim().runes.length >= 2 &&
          savedName.runes.length <= 24;
    } catch (_) {
      if (version == _sessionVersion) {
        _profileError =
            'Profil konnte nicht geladen werden. Bitte Verbindung prüfen und erneut versuchen.';
      }
    } finally {
      if (version == _sessionVersion) {
        _profileLoading = false;
        _notify();
      }
    }
  }

  Future<void> reloadProfile() async {
    final user = _auth.currentUser;
    if (user != null) await _acceptUser(user);
  }

  Future<bool> completeProfile({
    required String displayName,
    required String countryCode,
  }) async {
    if (_profileLoading) return false;
    final name = displayName.trim();
    if (name.runes.length < 2 ||
        name.runes.length > 24 ||
        name.contains(RegExp(r'[\x00-\x1F\x7F]')) ||
        !countryNames.containsKey(countryCode)) {
      _profileError =
          'Bitte einen Namen mit 2–24 Zeichen und ein gültiges Land wählen.';
      _notify();
      return false;
    }
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != _currentUser?.uid) {
      return false;
    }
    final version = _sessionVersion;
    _profileLoading = true;
    _profileError = null;
    _notify();
    try {
      await _profiles
          .save(user.uid, displayName: name, countryCode: countryCode)
          .timeout(const Duration(seconds: 15));
      if (_disposed || version != _sessionVersion) return false;
      _currentUser = _fromFirebase(user, name: name, countryCode: countryCode);
      _profileLoaded = true;
      try {
        await user.updateDisplayName(name);
      } catch (_) {}
      return true;
    } catch (_) {
      _profileError =
          'Profil konnte nicht gespeichert werden. Bitte erneut versuchen.';
      return false;
    } finally {
      if (version == _sessionVersion) {
        _profileLoading = false;
        _notify();
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  String _authError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'E-Mail oder Passwort stimmt nicht.';
      case 'invalid-email':
        return 'Bitte eine gültige E-Mail-Adresse eingeben.';
      case 'email-already-in-use':
        return 'Für diese E-Mail gibt es bereits ein Konto. Bitte anmelden.';
      case 'weak-password':
        return 'Das Passwort muss mindestens 6 Zeichen lang sein.';
      case 'user-disabled':
        return 'Dieses Konto ist deaktiviert.';
      case 'too-many-requests':
        return 'Zu viele Versuche. Bitte später erneut versuchen.';
      case 'network-request-failed':
        return 'Keine Verbindung. Bitte Internetverbindung prüfen.';
      case 'unauthorized-domain':
        return 'Diese Website ist für die Anmeldung noch nicht freigegeben.';
      case 'operation-not-allowed':
        return 'Diese Anmeldemethode ist derzeit nicht verfügbar.';
      case 'popup-blocked':
        return 'Bitte Pop-ups für diese Website erlauben und erneut versuchen.';
      default:
        return 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.';
    }
  }

  Future<bool> signInWithEmailPassword({
    required String emailOrUsername,
    required String password,
  }) async {
    if (_isLoading) return false;
    final email = emailOrUsername.trim();
    if (!email.contains('@') || password.isEmpty) {
      _errorMessage = 'Bitte deine E-Mail-Adresse und dein Passwort eingeben.';
      _notify();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) throw StateError('Missing Firebase user');
      await _acceptUser(credential.user);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authError(e);
      return false;
    } catch (_) {
      _errorMessage = 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.';
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> registerWithEmailPassword({
    String username = '',
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;
    if (!email.trim().contains('@') || password.length < 6) {
      _errorMessage =
          'Bitte eine gültige E-Mail und ein Passwort mit mindestens 6 Zeichen eingeben.';
      _notify();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) throw StateError('Missing Firebase user');
      await _acceptUser(credential.user);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authError(e);
      return false;
    } catch (_) {
      _errorMessage = 'Registrierung fehlgeschlagen. Bitte erneut versuchen.';
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> signInWithGoogle() async {
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      UserCredential credential;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        // Keep the popup directly attached to the user's click gesture.
        credential = await _auth.signInWithPopup(provider);
      } else {
        final account = await GoogleSignIn(scopes: ['email']).signIn();
        if (account == null) return false;
        final tokens = await account.authentication;
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: tokens.accessToken,
            idToken: tokens.idToken,
          ),
        );
      }
      if (credential.user == null) return false;
      await _acceptUser(credential.user);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'popup-closed-by-user' &&
          e.code != 'cancelled-popup-request') {
        _errorMessage = _authError(e);
      }
      return false;
    } catch (_) {
      _errorMessage =
          'Google-Anmeldung fehlgeschlagen. Bitte erneut versuchen.';
      return false;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> signInAsGuest() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final credential = await _auth.signInAnonymously();
      await _acceptUser(credential.user);
    } catch (_) {
      _currentUser = UserModel(
        uid: 'guest_${const Uuid().v4()}',
        email: '',
        displayName: 'Gast Trader',
        authProvider: 'guest',
        isGuest: true,
      );
    } finally {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
      }
      _isLoading = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      if (isAuthenticated) {
        _errorMessage = 'Abmelden fehlgeschlagen. Bitte erneut versuchen.';
        _notify();
        return;
      }
    }
    ++_sessionVersion;
    _currentUser = null;
    _profileLoaded = false;
    _profileError = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
