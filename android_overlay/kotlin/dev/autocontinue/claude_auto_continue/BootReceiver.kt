package dev.autocontinue.claude_auto_continue

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * After a reboot nothing can run until the user opens Claude to the right
 * conversation anyway, so we only remind them. We never start automation
 * blindly after boot.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences(NativeBridge.PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("running", false)) return
        prefs.edit().putBoolean("running", false).apply()
        NotificationHelper.notifyAttention(
            context,
            context.getString(R.string.notif_boot_title),
            context.getString(R.string.notif_boot_text)
        )
    }
}
