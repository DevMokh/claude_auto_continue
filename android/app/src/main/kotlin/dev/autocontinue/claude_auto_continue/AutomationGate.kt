package dev.autocontinue.claude_auto_continue

/**
 * Native kill switch. Every action in the accessibility service passes through
 * [begin]. It is closed by default, closed instantly by the notification Stop
 * button (even if Dart is stuck), and rate-limits consecutive actions.
 */
object AutomationGate {
    @Volatile
    var enabled: Boolean = false

    private var lastActionAt: Long = 0L
    private const val MIN_ACTION_GAP_MS = 600L

    /** Returns null when the action may proceed, otherwise the refusal reason. */
    @Synchronized
    fun begin(): String? {
        if (!enabled) return "automation_disabled"
        val now = System.currentTimeMillis()
        if (now - lastActionAt < MIN_ACTION_GAP_MS) return "rate_limited"
        lastActionAt = now
        return null
    }
}
