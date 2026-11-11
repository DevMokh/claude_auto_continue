package dev.autocontinue.claude_auto_continue

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Single MethodChannel entry point between Dart and everything native. */
object NativeBridge {
    const val CHANNEL = "dev.autocontinue/native"
    const val PREFS = "native_state"
    private const val REQ_NOTIFICATIONS = 4101

    @Volatile
    var activity: Activity? = null

    private var appContext: Context? = null
    private var channel: MethodChannel? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())

    // Accessibility tree walks are binder-heavy: never run them on the main thread.
    private val worker = Executors.newSingleThreadExecutor()

    fun attach(context: Context, messenger: BinaryMessenger) {
        appContext = context.applicationContext
        channel?.setMethodCallHandler(null)
        val ch = MethodChannel(messenger, CHANNEL)
        ch.setMethodCallHandler { call, result -> handle(call, result) }
        channel = ch
    }

    /** Native -> Dart: the notification Stop button was pressed. */
    fun notifyStopRequested() {
        main.post { channel?.invokeMethod("onStopRequested", null) }
    }

    fun onPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQ_NOTIFICATIONS) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
    }

    private fun async(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            val value: Any? = try {
                block()
            } catch (t: Throwable) {
                mapOf("ok" to false, "reason" to "exception:${t.javaClass.simpleName}", "error" to true)
            }
            main.post { result.success(value) }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val ctx = appContext
        if (ctx == null) {
            result.error("no_context", "Bridge not attached", null)
            return
        }
        when (call.method) {
            "accessibilityStatus" -> result.success(accessibilityStatus(ctx))
            "openAccessibilitySettings" -> {
                openSystemScreen(ctx, Settings.ACTION_ACCESSIBILITY_SETTINGS)
                result.success(true)
            }
            "isClaudeInstalled" -> result.success(
                ctx.packageManager.getLaunchIntentForPackage(ClaudeAccessibilityService.CLAUDE_PACKAGE) != null
            )
            "openClaude" -> result.success(openClaude(ctx))
            "getSnapshot" -> async(result) {
                val svc = ClaudeAccessibilityService.instance
                if (svc == null) {
                    mapOf<String, Any?>("accessibilityConnected" to false)
                } else {
                    svc.captureSnapshot(isOnline(ctx))
                }
            }
            "typeText" -> {
                val text = call.argument<String>("text") ?: ""
                async(result) {
                    ClaudeAccessibilityService.instance?.typeText(text)
                        ?: mapOf<String, Any?>("ok" to false, "reason" to "service_not_connected")
                }
            }
            "clickByLabels" -> {
                val labels = call.argument<List<String>>("labels") ?: emptyList()
                async(result) {
                    ClaudeAccessibilityService.instance?.clickByLabels(labels)
                        ?: mapOf<String, Any?>("ok" to false, "reason" to "service_not_connected")
                }
            }
            "dumpTree" -> async(result) {
                ClaudeAccessibilityService.instance?.dumpTree()
                    ?: "Accessibility service is not connected"
            }
            "setAutomationEnabled" -> {
                AutomationGate.enabled = call.argument<Boolean>("enabled") ?: false
                result.success(true)
            }
            "setRunningFlag" -> {
                ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putBoolean("running", call.argument<Boolean>("running") ?: false).apply()
                result.success(true)
            }
            "startForeground" -> {
                val i = Intent(ctx, MonitorForegroundService::class.java)
                    .setAction(MonitorForegroundService.ACTION_START)
                    .putExtra(MonitorForegroundService.EXTRA_TITLE, call.argument<String>("title"))
                    .putExtra(MonitorForegroundService.EXTRA_TEXT, call.argument<String>("text"))
                try {
                    ctx.startForegroundService(i)
                    result.success(true)
                } catch (t: Throwable) {
                    result.success(false)
                }
            }
            "stopForeground" -> {
                ctx.stopService(Intent(ctx, MonitorForegroundService::class.java))
                result.success(true)
            }
            "updateNotification" -> {
                NotificationHelper.notifyMonitor(
                    ctx,
                    call.argument<String>("title") ?: "",
                    call.argument<String>("text") ?: ""
                )
                result.success(true)
            }
            "notifyAttention" -> {
                NotificationHelper.notifyAttention(
                    ctx,
                    call.argument<String>("title") ?: "",
                    call.argument<String>("text") ?: ""
                )
                result.success(true)
            }
            "hasNotificationPermission" -> result.success(NotificationHelper.canNotify(ctx))
            "requestNotificationPermission" -> requestNotificationPermission(ctx, result)
            "isIgnoringBatteryOptimizations" -> {
                val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(ctx.packageName))
            }
            "openBatterySettings" -> {
                openSystemScreen(ctx, Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                result.success(true)
            }
            "setKeepScreenOn" -> {
                ScreenKeeper.set(ctx, call.argument<Boolean>("enabled") ?: false)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun accessibilityStatus(ctx: Context): Map<String, Any?> {
        val connected = ClaudeAccessibilityService.instance != null
        val flat = ComponentName(ctx, ClaudeAccessibilityService::class.java).flattenToString()
        val enabledList = Settings.Secure.getString(
            ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""
        val enabled = enabledList.split(':').any { it.equals(flat, ignoreCase = true) }
        return mapOf("connected" to connected, "enabled" to enabled)
    }

    private fun openSystemScreen(ctx: Context, action: String) {
        try {
            ctx.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (t: Throwable) {
            // Some OEM builds lack a screen; the user can navigate manually.
        }
    }

    private fun openClaude(ctx: Context): Boolean {
        val intent = ctx.packageManager
            .getLaunchIntentForPackage(ClaudeAccessibilityService.CLAUDE_PACKAGE) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            ctx.startActivity(intent)
            true
        } catch (t: Throwable) {
            false
        }
    }

    private fun requestNotificationPermission(ctx: Context, result: MethodChannel.Result) {
        if (NotificationHelper.canNotify(ctx)) {
            result.success(true)
            return
        }
        val act = activity
        if (act == null) {
            result.success(false)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        act.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFICATIONS)
    }

    private fun isOnline(ctx: Context): Boolean {
        val cm = ctx.getSystemService(ConnectivityManager::class.java) ?: return false
        val net = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(net) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}
