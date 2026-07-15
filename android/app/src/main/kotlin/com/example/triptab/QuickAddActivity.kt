package com.example.triptab

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

/**
 * Transparent Activity launched when the user taps the active-trip notification.
 *
 * KEY PERFORMANCE FIX: uses the engine pre-warmed by [MainActivity] via
 * [FlutterEngineCache].  The Activity attaches to an already-running Dart
 * isolate, so the bottom sheet appears in <100 ms instead of the 500 ms–2 s
 * cold-start that a plain [FlutterActivity] would incur.
 *
 * After Save or dismiss, [SystemNavigator.pop()] finishes this Activity and
 * the user is returned to whatever they were doing.  [onDestroy] broadcasts
 * [ACTION_EXPENSE_ADDED] so [MainActivity] can ping the primary engine to
 * refresh the trip timeline.
 */
class QuickAddActivity : FlutterActivity() {

    // ── Cached-engine contract ────────────────────────────────────────────────

    override fun getCachedEngineId(): String = MainActivity.QUICKADD_ENGINE_ID

    /**
     * We want the Activity to be transparent.  The cached-engine path does not
     * call [configureFlutterEngine], so we must set the background mode here.
     */
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    /**
     * Keep the pre-warmed engine alive when this Activity finishes so the
     * NEXT notification tap is also instant (avoids re-warming on every use).
     */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    // ── Route ─────────────────────────────────────────────────────────────────

    override fun getInitialRoute(): String = buildRoute()

    /**
     * After the Flutter UI is visible, push the correct route in case the
     * engine was already running from a previous use (cached engine reuse).
     * GoRouter's [Router.neglect] prevents this from adding a history entry.
     */
    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        flutterEngine?.navigationChannel?.pushRoute(buildRoute())
    }

    private fun buildRoute(): String {
        val tripId   = intent.getStringExtra(EXTRA_TRIP_ID)   ?: ""
        val tripName = intent.getStringExtra(EXTRA_TRIP_NAME) ?: "Trip"
        return "/quick-add/$tripId?name=${Uri.encode(tripName)}"
    }

    // ── Broadcast on close ────────────────────────────────────────────────────

    override fun onDestroy() {
        super.onDestroy()
        val broadcastIntent = Intent(ACTION_EXPENSE_ADDED).apply {
            setPackage(packageName)
            putExtra(EXTRA_TRIP_ID, intent.getStringExtra(EXTRA_TRIP_ID) ?: "")
        }
        sendBroadcast(broadcastIntent)
    }

    // ── Companion ─────────────────────────────────────────────────────────────

    companion object {
        const val EXTRA_TRIP_ID    = "trip_id"
        const val EXTRA_TRIP_NAME  = "trip_name"
        const val ACTION_EXPENSE_ADDED = "com.example.triptab.EXPENSE_ADDED"

        fun createPendingIntent(
            context: Context,
            tripId: String,
            tripName: String,
        ): PendingIntent {
            val intent = Intent(context, QuickAddActivity::class.java).apply {
                putExtra(EXTRA_TRIP_ID, tripId)
                putExtra(EXTRA_TRIP_NAME, tripName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}
