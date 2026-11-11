package dev.autocontinue.claude_auto_continue

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the process alive (and the cached Flutter engine with it) while
 * monitoring. NOT sticky on purpose: after a kill there is no Dart state to
 * resume, so the user must reopen the app (it then restores and re-verifies).
 */
class MonitorForegroundService : Service() {

    companion object {
        const val ACTION_START = "dev.autocontinue.action.START"
        const val ACTION_STOP = "dev.autocontinue.action.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"

        @Volatile
        var isRunning: Boolean = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // Close the native gate FIRST, then tell Dart.
            AutomationGate.enabled = false
            ScreenKeeper.set(this, false)
            NativeBridge.notifyStopRequested()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: getString(R.string.acs_service_label)
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        val notification = NotificationHelper.buildMonitor(this, title, text)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NotificationHelper.ID_MONITOR,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NotificationHelper.ID_MONITOR, notification)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}
