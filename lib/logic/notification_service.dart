import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_planner.dart';

/// Public web-push (VAPID) key of the Firebase project; not a secret.
const fcmVapidKey = String.fromEnvironment(
  'FCM_VAPID_KEY',
  defaultValue:
      'BOUhpwoX8jns090BMi3aJJ085f6NHLKOASFwkYnfTwd59BHIO82R4i2x-RuMtgu3sK5t-5TdMV7lk8FvPYT1GM4',
);

/// Platform part, replaceable in tests.
abstract class LocalNotifier {
  Future<void> init();
  Future<void> show(int id, String title, String body);
  Future<void> replaceScheduled(List<PlannedNotification> planned);
}

bool get _supportsLocal =>
    !kIsWeb &&
    const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

class PlatformLocalNotifier implements LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'game_events',
      'Spiel & Orders',
      channelDescription: 'Orders, Börsenzeiten, Kredite und Erfolge',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    if (!_supportsLocal) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'price_alerts',
        'Kursalarme',
        description: 'Wenn ein Kurs deine Schwelle erreicht',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'game_events',
        'Spiel & Orders',
        description: 'Orders, Börsenzeiten, Kredite und Erfolge',
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<void> show(int id, String title, String body) async {
    if (!_supportsLocal) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  @override
  Future<void> replaceScheduled(List<PlannedNotification> planned) async {
    if (!_supportsLocal) return;
    await _plugin.cancelAllPendingNotifications();
    for (final n in planned) {
      await _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        // UTC avoids needing the device time-zone database.
        scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
        notificationDetails: _details,
        // Inexact: no exact-alarm permission needed; a few minutes of drift
        // is fine for market/loan reminders.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

typedef PushText = ({String title, String body});

/// Permission, per-category switches, device-token registration and
/// local/scheduled notifications. Never throws into the UI.
class NotificationService extends ChangeNotifier {
  static const _prefix = 'tg_notify_';

  final LocalNotifier _local;
  final FirebaseMessaging? _messagingOverride;
  final FirebaseFirestore? _firestoreOverride;
  final _enabled = {for (final c in NotificationCategory.values) c: true};
  final _foreground = StreamController<PushText>.broadcast();
  StreamSubscription<RemoteMessage>? _onMessage;
  StreamSubscription<String>? _onRefresh;
  bool _permissionGranted = false;
  bool _ready = false;
  String? _uid;
  String? _token;
  int _nextId = 1000;

  NotificationService({
    LocalNotifier? local,
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _local = local ?? PlatformLocalNotifier(),
       _messagingOverride = messaging,
       _firestoreOverride = firestore;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  bool get permissionGranted => _permissionGranted;
  bool isEnabled(NotificationCategory c) => _enabled[c] ?? true;

  /// Push messages that arrive while the app is open (shown in-app).
  Stream<PushText> get foregroundMessages => _foreground.stream;

  bool get _supportsPush =>
      kIsWeb ||
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  Future<void> init() async {
    if (_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final c in NotificationCategory.values) {
        _enabled[c] = prefs.getBool('$_prefix${c.name}') ?? true;
      }
      await _local.init();
      if (_supportsPush) {
        final settings = await _messaging.getNotificationSettings();
        _permissionGranted =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        _onMessage = FirebaseMessaging.onMessage.listen((m) {
          final n = m.notification;
          if (n != null) {
            _foreground.add((title: n.title ?? '', body: n.body ?? ''));
          }
        });
        // The registration-token API is what firebase-admin sendEachForMulticast
        // expects; the newer register()/onRegistered yields installation IDs.
        // ignore: deprecated_member_use
        _onRefresh = _messaging.onTokenRefresh.listen((t) {
          _token = t;
          unawaited(_saveToken());
        });
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
    notifyListeners();
  }

  Future<void> setEnabled(NotificationCategory c, bool value) async {
    _enabled[c] = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix${c.name}', value);
    } catch (_) {}
  }

  /// Asks for permission (must follow a user gesture on the web).
  Future<bool> requestPermission() async {
    try {
      if (_supportsPush) {
        final s = await _messaging.requestPermission();
        _permissionGranted =
            s.authorizationStatus == AuthorizationStatus.authorized ||
            s.authorizationStatus == AuthorizationStatus.provisional;
        if (_permissionGranted) await _saveToken();
      }
    } catch (e) {
      debugPrint('Notification permission failed: $e');
    }
    notifyListeners();
    return _permissionGranted;
  }

  /// Links this device to the signed-in player (or unlinks with null).
  Future<void> bindUser(String? uid) async {
    _uid = uid;
    if (uid != null && _permissionGranted) await _saveToken();
  }

  Future<void> _saveToken() async {
    final uid = _uid;
    if (uid == null || !_supportsPush || !_permissionGranted) return;
    try {
      // ignore: deprecated_member_use
      _token ??= await _messaging.getToken(
        vapidKey: kIsWeb && fcmVapidKey.isNotEmpty ? fcmVapidKey : null,
      );
      final token = _token;
      if (token == null) return;
      await _firestore.collection('deviceTokens').doc(token).set({
        'uid': uid,
        'platform': _platform,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Saving push token failed: $e');
    }
  }

  /// Call before signing out so this device stops receiving the old
  /// player's alerts.
  Future<void> unregisterDevice() async {
    final token = _token;
    _uid = null;
    if (token == null) return;
    try {
      await _firestore.collection('deviceTokens').doc(token).delete();
    } catch (e) {
      debugPrint('Removing push token failed: $e');
    }
  }

  Future<void> showNow(
    NotificationCategory category,
    String title,
    String body,
  ) async {
    if (!isEnabled(category)) return;
    try {
      await _local.show(
        _nextId = _nextId >= 1999 ? 1000 : _nextId + 1,
        title,
        body,
      );
    } catch (e) {
      debugPrint('Showing notification failed: $e');
    }
  }

  /// Replaces all scheduled reminders with [planned], minus disabled categories.
  Future<void> syncSchedule(List<PlannedNotification> planned) async {
    try {
      await _local.replaceScheduled(
        planned.where((p) => isEnabled(p.category)).toList(),
      );
    } catch (e) {
      debugPrint('Scheduling notifications failed: $e');
    }
  }

  @override
  void dispose() {
    _onMessage?.cancel();
    _onRefresh?.cancel();
    _foreground.close();
    super.dispose();
  }
}
