import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local notification for when a rest / hold / warm-up timer ends while the
/// app is in the background. iOS suspends the app (so no beeps play); this is
/// the only way to alert the user. Android keeps the app alive long enough for
/// the in-app beeps, so this is iOS only.
class TimerNotifications {
  TimerNotifications._();

  static const int _kTimerEndId = 1001;
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get _supported => Platform.isIOS;

  static Future<bool> _ensureInitialized() async {
    if (!_supported) return false;
    if (_initialized) return true;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          // Don't prompt on init; we ask the first time a timer starts.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
      _initialized = true;
    } catch (_) {
      // Ignore notification setup errors; timers still work in the app.
    }
    return _initialized;
  }

  /// Shows the system permission prompt the first time; later calls are no-ops.
  static Future<void> requestPermission() async {
    if (!await _ensureInitialized()) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
    } catch (_) {
      // Ignore
    }
  }

  static Future<void> scheduleTimerEnd({
    required int inSeconds,
    required String title,
    required String body,
  }) async {
    if (inSeconds <= 0) return;
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.zonedSchedule(
        id: _kTimerEndId,
        scheduledDate: tz.TZDateTime.now(
          tz.UTC,
        ).add(Duration(seconds: inSeconds)),
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (_) {
      // Ignore
    }
  }

  static Future<void> cancelTimerEnd() async {
    if (!_supported || !_initialized) return;
    try {
      await _plugin.cancel(id: _kTimerEndId);
    } catch (_) {
      // Ignore
    }
  }
}
