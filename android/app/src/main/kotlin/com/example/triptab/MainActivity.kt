package com.example.triptab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes a "triptab/notifications" MethodChannel so Flutter can trigger
 * the native NotificationHelper.
 *
 * KEY PERFORMANCE FIX — pre-warms a Flutter engine for the QuickAdd overlay
 * as soon as MainActivity starts.  When the user taps the notification,
 * [QuickAddActivity] picks up the cached engine from [FlutterEngineCache]
 * instead of booting a cold one (which takes ~500 ms–2 s).
 *
 * Also receives [QuickAddActivity.ACTION_EXPENSE_ADDED] and pings the
 * primary Flutter engine via "triptab/refresh" to invalidate providers.
 */
class MainActivity : FlutterActivity() {

    companion object {
        /** ID used to cache / retrieve the pre-warmed engine. */
        const val QUICKADD_ENGINE_ID = "quickadd_engine"
    }

    private val notificationChannelName = "triptab/notifications"
    private val refreshChannelName      = "triptab/refresh"

    private var refreshChannel: MethodChannel? = null

    private val expenseAddedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val tripId = intent?.getStringExtra(QuickAddActivity.EXTRA_TRIP_ID) ?: ""
            runOnUiThread {
                refreshChannel?.invokeMethod("onExpenseAdded", tripId)
            }
        }
    }

    // ── Engine setup ──────────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Notification control channel (main engine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showTripNotification" -> {
                        val tripId   = call.argument<String>("tripId")   ?: ""
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

        // Refresh channel — native → Flutter (push direction)
        refreshChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            refreshChannelName
        )

        // Pre-warm the QuickAdd engine so it is instant on first tap.
        warmUpQuickAddEngine()
    }

    /**
     * Creates a second Flutter engine dedicated to the QuickAdd overlay and
     * stores it in [FlutterEngineCache].  The engine executes the Dart
     * entrypoint so it is fully initialised and ready when the notification
     * is tapped — the Activity just attaches to it with zero cold-start cost.
     */
    private fun warmUpQuickAddEngine() {
        // Only warm up once; if it is already cached, skip.
        if (FlutterEngineCache.getInstance().contains(QUICKADD_ENGINE_ID)) return

        val engine = FlutterEngine(applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(QUICKADD_ENGINE_ID, engine)
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onResume() {
        super.onResume()
        val filter = IntentFilter(QuickAddActivity.ACTION_EXPENSE_ADDED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(expenseAddedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(expenseAddedReceiver, filter)
        }
    }

    override fun onPause() {
        super.onPause()
        try { unregisterReceiver(expenseAddedReceiver) }
        catch (_: IllegalArgumentException) { /* not registered — safe to ignore */ }
    }
}
