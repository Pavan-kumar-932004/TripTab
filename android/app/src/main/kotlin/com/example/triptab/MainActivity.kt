package com.example.triptab

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes a "triptab/notifications" MethodChannel so Flutter can trigger
 * the native NotificationHelper without going through flutter_local_notifications.
 *
 * Methods:
 *   showTripNotification(tripId: String, tripName: String)
 *   hideTripNotification()
 */
class MainActivity : FlutterActivity() {

    private val channelName = "triptab/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showTripNotification" -> {
                        val tripId = call.argument<String>("tripId") ?: ""
                        val tripName = call.argument<String>("tripName") ?: "Trip"
                        NotificationHelper.showTripNotification(this, tripId, tripName)
                        result.success(null)
                    }
                    "hideTripNotification" -> {
                        NotificationHelper.hideTripNotification(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
