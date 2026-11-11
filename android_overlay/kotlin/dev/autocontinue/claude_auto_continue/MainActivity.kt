package dev.autocontinue.claude_auto_continue

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * The Flutter engine is cached and NOT destroyed with the Activity, so the Dart
 * automation engine keeps running (kept alive by the foreground service) after
 * the user swipes the app away from recents.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val ENGINE_ID = "auto_continue_engine"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NativeBridge.activity = this
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(ENGINE_ID)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        if (FlutterEngineCache.getInstance().get(ENGINE_ID) == null) {
            super.configureFlutterEngine(flutterEngine)
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
            NativeBridge.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onDestroy() {
        if (NativeBridge.activity === this) NativeBridge.activity = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        NativeBridge.onPermissionsResult(requestCode, grantResults)
    }
}
