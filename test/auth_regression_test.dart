import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trading_game/logic/auth_provider.dart';
import 'package:trading_game/data/repositories/player_profile_repository.dart';

class ProfileUser extends Fake implements User {
  @override
  String get uid => 'real-user';
  @override
  String? get email => 'trader@example.com';
  @override
  String? get displayName => 'Google Name';
  @override
  String? get photoURL => null;
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [];
  @override
  Future<void> updateDisplayName(String? displayName) async {}
}

class ProfileAuth extends FailedFirebaseAuth {
  final user = ProfileUser();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => Stream.value(user);
}

class MemoryProfiles implements PlayerProfileRepository {
  Map<String, dynamic>? data;
  bool failSave = false;
  @override
  Future<Map<String, dynamic>?> load(String uid) async => data;
  @override
  Future<void> save(
    String uid, {
    required String displayName,
    required String countryCode,
  }) async {
    if (failSave) throw StateError('offline');
    data = {'displayName': displayName, 'countryCode': countryCode};
  }
}

class FailedFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  Future<UserCredential> signInAnonymously() async =>
      throw FirebaseAuthException(code: 'operation-not-allowed');
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => throw FirebaseAuthException(code: 'invalid-credential');
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => throw FirebaseAuthException(code: 'email-already-in-use');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AuthProvider> provider() async {
    final auth = AuthProvider(firebaseAuth: FailedFirebaseAuth());
    while (auth.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    addTearDown(auth.dispose);
    return auth;
  }

  test('failed Firebase login cannot manufacture a signed-in user', () async {
    final auth = await provider();
    expect(
      await auth.signInWithEmailPassword(
        emailOrUsername: 'trader@example.com',
        password: 'wrong-password',
      ),
      isFalse,
    );
    expect(auth.isAuthenticated, isFalse);
    expect(auth.errorMessage, isNotNull);
  });

  test('failed registration cannot manufacture a signed-in user', () async {
    final auth = await provider();
    expect(
      await auth.registerWithEmailPassword(
        username: 'Trader',
        email: 'trader@example.com',
        password: 'test-password',
      ),
      isFalse,
    );
    expect(auth.isAuthenticated, isFalse);
  });

  test(
    'a cached local profile is not proof of Firebase authentication',
    () async {
      SharedPreferences.setMockInitialValues({
        'tg_auth_user': jsonEncode({
          'uid': 'usr_old_fake',
          'email': 'trader@example.com',
          'displayName': 'Old fake',
          'isGuest': false,
          'authProvider': 'password',
        }),
      });
      final auth = await provider();
      expect(auth.isAuthenticated, isFalse);
    },
  );

  test(
    'first real login requires name and country, restored profile skips setup',
    () async {
      final profiles = MemoryProfiles();
      final auth = AuthProvider(
        firebaseAuth: ProfileAuth(),
        profiles: profiles,
      );
      addTearDown(auth.dispose);
      while (auth.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(auth.needsProfile, isTrue);
      expect(
        await auth.completeProfile(displayName: 'A', countryCode: 'AT'),
        isFalse,
      );
      expect(
        await auth.completeProfile(displayName: 'Trader', countryCode: 'XX'),
        isFalse,
      );
      expect(
        await auth.completeProfile(
          displayName: '  Trader  ',
          countryCode: 'AT',
        ),
        isTrue,
      );
      expect(auth.needsProfile, isFalse);
      expect(auth.currentUser!.displayName, 'Trader');
      expect(auth.currentUser!.countryCode, 'AT');
      await auth.reloadProfile();
      expect(auth.needsProfile, isFalse);
      expect(auth.currentUser!.displayName, 'Trader');
    },
  );

  test('failed profile save keeps first-login gate closed', () async {
    final profiles = MemoryProfiles()..failSave = true;
    final auth = AuthProvider(firebaseAuth: ProfileAuth(), profiles: profiles);
    addTearDown(auth.dispose);
    while (auth.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      await auth.completeProfile(displayName: 'Trader', countryCode: 'DE'),
      isFalse,
    );
    expect(auth.needsProfile, isTrue);
    expect(auth.profileError, isNotNull);
  });
}
