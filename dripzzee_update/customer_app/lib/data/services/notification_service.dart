import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../repositories/user_repository.dart';

/// Must be a top-level function. Notification payloads are shown by the
/// system tray automatically while the app is in the background, so nothing
/// extra is needed here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

typedef NotificationOpenHandler = void Function(Map<String, dynamic> data);
typedef ForegroundNotificationHandler = void Function(
  String title,
  String body,
  Map<String, dynamic> data,
);

/// Registers this device's FCM token on the signed-in user and routes
/// notification taps. Payload contract (set by Cloud Functions):
///   {type: 'order', orderId} | {type: 'product', productId} | {type: 'return', orderId}
class NotificationService {
  NotificationService(this._users);

  final UserRepository _users;
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _uid;
  String? _token;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> start({
    required String uid,
    required NotificationOpenHandler onOpen,
    required ForegroundNotificationHandler onForeground,
  }) async {
    if (_uid == uid) return;
    await stop(removeToken: false);
    _uid = uid;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      _token = await _messaging.getToken();
      final token = _token;
      if (token != null) await _users.addFcmToken(uid, token);
      _subs.add(_messaging.onTokenRefresh.listen((t) async {
        _token = t;
        final current = _uid;
        if (current != null) {
          try {
            await _users.addFcmToken(current, t);
          } catch (_) {}
        }
      }));
    } catch (_) {
      // Notifications are optional; the app works without them.
    }

    _subs.add(FirebaseMessaging.onMessage.listen((m) {
      onForeground(
        m.notification?.title ?? 'Dripzzee',
        m.notification?.body ?? '',
        m.data,
      );
    }));
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen(m.data)));

    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) onOpen(initial.data);
    } catch (_) {}
  }

  Future<void> stop({bool removeToken = true}) async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final uid = _uid;
    final token = _token;
    _uid = null;
    if (removeToken && uid != null && token != null) {
      try {
        await _users.removeFcmToken(uid, token);
      } catch (_) {}
    }
  }
}
