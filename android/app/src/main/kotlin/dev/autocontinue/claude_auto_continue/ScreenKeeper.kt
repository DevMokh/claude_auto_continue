package dev.autocontinue.claude_auto_continue

import android.content.Context
import android.os.PowerManager

/**
 * Optional "keep the screen on while monitoring". Accessibility cannot work on
 * a turned-off or locked screen, so overnight use needs this (plus no secure
 * lock screen). Uses the deprecated SCREEN_BRIGHT wake lock because there is no
 * non-deprecated way to do this from a service. Hard 12 h safety timeout.
 */
object ScreenKeeper {
    private var lock: PowerManager.WakeLock? = null

    @Suppress("DEPRECATION")
    @Synchronized
    fun set(ctx: Context, enabled: Boolean) {
        if (enabled) {
            if (lock?.isHeld == true) return
            val pm = ctx.applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            val l = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "ClaudeAutoContinue:screen"
            )
            l.setReferenceCounted(false)
            l.acquire(12L * 60L * 60L * 1000L)
            lock = l
        } else {
            lock?.let { if (it.isHeld) it.release() }
            lock = null
        }
    }
}
