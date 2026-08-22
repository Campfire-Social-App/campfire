package com.campfire.campfire

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * The foreground service a call runs under. It holds no state and does no work
 * — being there is the work.
 *
 * Android needs it for two separate reasons:
 *
 *  * From Android 11, an app that is not in the foreground loses the
 *    microphone, so a call would go silent the moment the user switched apps.
 *  * From Android 10, `MediaProjectionManager.getMediaProjection` throws unless
 *    a foreground service of type `mediaProjection` is already running (and
 *    from Android 14 the type must be declared with a matching permission).
 *
 * flutter_webrtc captures both without shipping a service, so this one stands
 * in. Started from Dart when a room is joined, promoted when a screen share
 * begins, stopped when the room is left — see `lib/core/call_service.dart`.
 */
class CallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val sharingScreen = intent?.getBooleanExtra(EXTRA_SCREEN_SHARE, false) ?: false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (sharingScreen) {
                types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(NOTIFICATION_ID, buildNotification(sharingScreen), types)
        } else {
            startForeground(NOTIFICATION_ID, buildNotification(sharingScreen))
        }

        // Not sticky: if the process died the call died with it, and a service
        // restarted without one would be a notification for nothing.
        return START_NOT_STICKY
    }

    private fun buildNotification(sharingScreen: Boolean): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Calls", NotificationManager.IMPORTANCE_LOW),
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        // Tapping the notification comes back to the call rather than starting a
        // second copy of the app.
        val resume = Intent(this, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        return builder
            .setContentTitle("Campfire")
            .setContentText(if (sharingScreen) "Sharing your screen" else "In a voice call")
            .setSmallIcon(android.R.drawable.stat_sys_speakerphone)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    resume,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "campfire_call"
        private const val NOTIFICATION_ID = 8231
        private const val EXTRA_SCREEN_SHARE = "screen_share"

        fun start(context: Context, sharingScreen: Boolean) {
            val intent = Intent(context, CallService::class.java)
                .putExtra(EXTRA_SCREEN_SHARE, sharingScreen)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CallService::class.java))
        }
    }
}
