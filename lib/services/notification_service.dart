import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Calls the native Android [NotificationHelper] via a MethodChannel.
///
/// The native side posts an ongoing notification whose contentIntent
/// points directly to [QuickAddActivity] — a transparent Activity that
/// shows the bottom sheet over whatever app the user is currently in.
///
/// This replaces the previous flutter_local_notifications + RemoteInput
/// approach, giving us precise control over the Intent target.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const _channel = MethodChannel('triptab/notifications');

  Future<void> showTripActiveNotification(
      String tripId, String tripName) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    // Android 13+ runtime permission
    final status = await Permission.notification.status;
    if (status.isDenied || status.isRestricted) {
      final result = await Permission.notification.request();
      if (!result.isGranted) {
        debugPrint('[NotificationService] POST_NOTIFICATIONS denied.');
        return;
      }
    }

    await _channel.invokeMethod('showTripNotification', {
      'tripId': tripId,
      'tripName': tripName,
    });
  }

  Future<void> hideTripActiveNotification() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('hideTripNotification');
  }

  /// No-op: was used by the old flutter_local_notifications init.
  Future<void> init() async {}
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
