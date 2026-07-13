package com.example.triptab

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Transparent Activity launched when the user taps the active-trip notification.
 *
 * The previous app remains visible through the dimmed window. Flutter opens
 * the QuickAdd bottom sheet immediately via the /quick-add/:tripId route.
 * After save or dismiss, [SystemNavigator.pop()] finishes this Activity and
 * the user is returned to whatever they were doing.
 */
class QuickAddActivity : FlutterActivity() {

    override fun getInitialRoute(): String {
        val tripId = intent.getStringExtra(EXTRA_TRIP_ID) ?: ""
        val tripName = intent.getStringExtra(EXTRA_TRIP_NAME) ?: "Trip"
        return "/quick-add/$tripId?name=${Uri.encode(tripName)}"
    }

    companion object {
        const val EXTRA_TRIP_ID = "trip_id"
        const val EXTRA_TRIP_NAME = "trip_name"

        /**
         * Creates a PendingIntent that launches QuickAddActivity with the
         * given trip details. Called from NotificationHelper (Kotlin side).
         */
        fun createPendingIntent(context: Context, tripId: String, tripName: String): PendingIntent {
            val intent = Intent(context, QuickAddActivity::class.java).apply {
                putExtra(EXTRA_TRIP_ID, tripId)
                putExtra(EXTRA_TRIP_NAME, tripName)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
