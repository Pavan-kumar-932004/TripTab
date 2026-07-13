package com.example.triptab

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Posts the active-trip ongoing notification via Android's native APIs.
 *
 * Using the native API (rather than flutter_local_notifications) gives us
 * precise control over the contentIntent — we point it directly to
 * QuickAddActivity so tapping the notification opens the transparent overlay.
 *
 * Called from MainActivity via a MethodChannel.
 */
object NotificationHelper {

    private const val CHANNEL_ID = "trip_active_channel"
    private const val NOTIFICATION_ID = 888

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Active Trip",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Tap to quickly log an expense for your active trip"
                setShowBadge(true)
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    fun showTripNotification(context: Context, tripId: String, tripName: String) {
        ensureChannel(context)

        val contentIntent = QuickAddActivity.createPendingIntent(context, tripId, tripName)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("🧳 $tripName")
            .setContentText("Trip active • Tap to add expense")
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(contentIntent)
            .build()

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    fun hideTripNotification(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }
}
