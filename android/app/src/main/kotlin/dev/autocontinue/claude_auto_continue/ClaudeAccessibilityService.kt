package dev.autocontinue.claude_auto_continue

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Reads ONLY the official Claude app window (enforced twice: `packageNames` in
 * accessibility_service_config.xml and an explicit package check here).
 *
 * Polling model: Flutter asks for a snapshot; events are intentionally ignored.
 * Password fields are never read. Every action re-finds its target and refuses
 * on zero or ambiguous matches.
 */
class ClaudeAccessibilityService : AccessibilityService() {

    companion object {
        const val CLAUDE_PACKAGE = "com.anthropic.claude"

        @Volatile
        var instance: ClaudeAccessibilityService? = null

        private const val MAX_NODES = 2500
        private const val MAX_DEPTH = 80
        private const val MAX_TEXT = 300
        private const val MAX_TEXTS = 400
        private const val MAX_DUMP_LINES = 500
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Intentionally empty: state is pulled via captureSnapshot().
    }

    override fun onInterrupt() {}

    // ---------------------------------------------------------------- snapshot

    fun captureSnapshot(online: Boolean): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        out["accessibilityConnected"] = true
        out["online"] = online
        val root = rootInActiveWindow
        val pkg = root?.packageName?.toString()
        out["packageName"] = pkg
        if (root == null || pkg != CLAUDE_PACKAGE) {
            out["claudeInForeground"] = false
            return out
        }
        out["claudeInForeground"] = true

        val texts = LinkedHashSet<String>()
        val controls = ArrayList<Map<String, Any?>>()
        var hasPassword = false

        walk(root) { node ->
            if (node.isPassword) {
                hasPassword = true
            } else if (node.isVisibleToUser) {
                val text = clean(node.text)
                val desc = clean(node.contentDescription)
                if (!node.isEditable) {
                    if (text.isNotEmpty() && texts.size < MAX_TEXTS) texts.add(text)
                    if (desc.isNotEmpty() && texts.size < MAX_TEXTS) texts.add(desc)
                }
                if (node.isClickable || node.isEditable) {
                    val c = HashMap<String, Any?>()
                    c["desc"] = desc
                    c["text"] = if (node.isEditable) editableText(node) else text
                    c["className"] = node.className?.toString()?.substringAfterLast('.') ?: ""
                    c["viewId"] = node.viewIdResourceName ?: ""
                    c["editable"] = node.isEditable
                    c["clickable"] = node.isClickable
                    c["enabled"] = node.isEnabled
                    controls.add(c)
                }
            }
        }

        out["texts"] = ArrayList(texts)
        out["controls"] = controls
        out["hasPasswordField"] = hasPassword
        return out
    }

    // ----------------------------------------------------------------- actions

    fun typeText(text: String): Map<String, Any?> {
        AutomationGate.begin()?.let { return fail(it) }
        val root = rootInActiveWindow ?: return fail("no_window")
        if (root.packageName?.toString() != CLAUDE_PACKAGE) return fail("not_claude")

        val editables = ArrayList<AccessibilityNodeInfo>()
        walk(root) { n ->
            if (n.isVisibleToUser && n.isEditable && !n.isPassword) {
                editables.add(n)
            }
        }
        if (editables.isEmpty()) return fail("composer_not_found")
        if (editables.size > 1) return fail("composer_ambiguous")
        val node = editables[0]
        if (!node.isEnabled) return fail("composer_disabled")
        // Never overwrite something the user typed.
        if (editableText(node).isNotEmpty()) return fail("composer_not_empty")

        val args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        val ok = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        return if (ok) success() else fail("set_text_failed")
    }

    /**
     * Clicks the single visible, enabled control whose text or description EQUALS
     * one of [labels]. Zero matches, several matches, or a disabled target all
     * mean: do nothing and report why.
     */
    fun clickByLabels(labels: List<String>): Map<String, Any?> {
        AutomationGate.begin()?.let { return fail(it) }
        val root = rootInActiveWindow ?: return fail("no_window")
        if (root.packageName?.toString() != CLAUDE_PACKAGE) return fail("not_claude")

        val wanted = labels.map { it.trim().lowercase() }.filter { it.isNotEmpty() }.toSet()
        if (wanted.isEmpty()) return fail("no_labels")

        val matches = ArrayList<AccessibilityNodeInfo>()
        walk(root) { n ->
            if (n.isVisibleToUser && !n.isPassword && !n.isEditable) {
                val t = n.text?.toString()?.trim()?.lowercase()
                val d = n.contentDescription?.toString()?.trim()?.lowercase()
                if ((t != null && t in wanted) || (d != null && d in wanted)) {
                    matches.add(n)
                }
            }
        }
        if (matches.isEmpty()) return fail("not_found")

        val targets = LinkedHashSet<AccessibilityNodeInfo>()
        for (m in matches) {
            clickableTarget(m)?.let { targets.add(it) }
        }
        if (targets.isEmpty()) return fail("not_clickable")

        var list: List<AccessibilityNodeInfo> = targets.toList()
        if (list.size > 1) {
            val buttons = list.filter { it.className?.toString()?.contains("Button") == true }
            if (buttons.size == 1) list = buttons
        }
        if (list.size != 1) return fail("ambiguous")

        val target = list[0]
        if (!target.isEnabled) return fail("disabled")
        val ok = target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        return if (ok) success() else fail("click_failed")
    }

    // ------------------------------------------------------------- calibration

    fun dumpTree(): String {
        val root = rootInActiveWindow ?: return "No active window (is Claude open and the screen on?)"
        if (root.packageName?.toString() != CLAUDE_PACKAGE) {
            return "Active window is not Claude (package=${root.packageName})"
        }
        val sb = StringBuilder()
        var lines = 0

        fun rec(node: AccessibilityNodeInfo, depth: Int) {
            if (lines >= MAX_DUMP_LINES || depth > MAX_DEPTH) return
            val indent = "  ".repeat(minOf(depth, 20))
            if (node.isPassword) {
                sb.append(indent).append("[password field omitted]\n")
                lines++
                return
            }
            val flags = ArrayList<String>()
            if (node.isClickable) flags.add("clickable")
            if (node.isEditable) flags.add("editable")
            if (!node.isEnabled) flags.add("disabled")
            if (!node.isVisibleToUser) flags.add("hidden")
            sb.append(indent)
                .append(node.className?.toString()?.substringAfterLast('.') ?: "?")
                .append(" id=").append(node.viewIdResourceName ?: "-")
                .append(" text=\"").append(clean(node.text)).append("\"")
                .append(" desc=\"").append(clean(node.contentDescription)).append("\"")
                .append(" [").append(flags.joinToString(",")).append("]\n")
            lines++
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                rec(child, depth + 1)
            }
        }
        rec(root, 0)
        if (lines >= MAX_DUMP_LINES) sb.append("... (truncated)\n")
        return sb.toString()
    }

    // ----------------------------------------------------------------- helpers

    private fun walk(root: AccessibilityNodeInfo, visit: (AccessibilityNodeInfo) -> Unit) {
        val stack = ArrayDeque<Pair<AccessibilityNodeInfo, Int>>()
        stack.addLast(Pair(root, 0))
        var visited = 0
        while (stack.isNotEmpty() && visited < MAX_NODES) {
            val (node, depth) = stack.removeLast()
            visited++
            visit(node)
            if (depth < MAX_DEPTH) {
                for (i in node.childCount - 1 downTo 0) {
                    val child = node.getChild(i) ?: continue
                    stack.addLast(Pair(child, depth + 1))
                }
            }
        }
    }

    private fun clickableTarget(start: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var cur: AccessibilityNodeInfo? = start
        var hops = 0
        while (cur != null && hops <= 3) {
            if (cur.isClickable) return cur
            cur = cur.parent
            hops++
        }
        return null
    }

    private fun clean(cs: CharSequence?): String {
        val s = cs?.toString()?.trim() ?: ""
        return if (s.length > MAX_TEXT) s.substring(0, MAX_TEXT) else s
    }

    private fun editableText(node: AccessibilityNodeInfo): String {
        if (node.isShowingHintText) return ""
        return clean(node.text)
    }

    private fun success(): Map<String, Any?> = mapOf("ok" to true)

    private fun fail(reason: String): Map<String, Any?> = mapOf("ok" to false, "reason" to reason)
}
