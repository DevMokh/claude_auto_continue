package dev.autocontinue.claude_auto_continue

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build

object NotificationHelper {
    const val CHANNEL_MONITOR = "monitoring"
    const val CHANNEL_ATTENTION = "attention"
    const val ID_MONITOR = 1001
    const val ID_ATTENTION = 1002

    fun ensureChannels(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_MONITOR,
                ctx.getString(R.string.ch_monitor_name),
                NotificationManager.IMPORTANCE_LOW
            )
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ATTENTION,
                ctx.getString(R.string.ch_attention_name),
                NotificationManager.IMPORTANCE_HIGH
            )
        )
    }

    fun canNotify(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 33) return true
        return ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun openAppIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            ctx, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    fun buildMonitor(ctx: Context, title: String, text: String): Notification {
        ensureChannels(ctx)
        val stop = PendingIntent.getService(
            ctx,
            1,
            Intent(ctx, MonitorForegroundService::class.java)
                .setAction(MonitorForegroundService.ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val action = Notification.Action.Builder(
            Icon.createWithResource(ctx, R.drawable.ic_stat_auto),
            ctx.getString(R.string.notif_stop),
            stop
        ).build()
        return Notification.Builder(ctx, CHANNEL_MONITOR)
            .setSmallIcon(R.drawable.ic_stat_auto)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openAppIntent(ctx))
            .addAction(action)
            .build()
    }

    /** Updates the ongoing notification, but only while the service is alive. */
    fun notifyMonitor(ctx: Context, title: String, text: String) {
        if (!MonitorForegroundService.isRunning || !canNotify(ctx)) return
        ctx.getSystemService(NotificationManager::class.java)
            .notify(ID_MONITOR, buildMonitor(ctx, title, text))
    }

    fun notifyAttention(ctx: Context, title: String, text: String) {
        if (!canNotify(ctx)) return
        ensureChannels(ctx)
        val n = Notification.Builder(ctx, CHANNEL_ATTENTION)
            .setSmallIcon(R.drawable.ic_stat_auto)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(ctx))
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(ID_ATTENTION, n)
    }
}
