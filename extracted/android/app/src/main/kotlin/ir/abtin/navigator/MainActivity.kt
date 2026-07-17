package ir.abtin.navigator

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * لایه بومی Android:
 * - Engine routing (GraphHopper/Valhalla) — stub تا باینری اضافه شود
 * - Vosk STT — stub
 * - Deep link / geo intent
 * - Android Auto projection hooks
 */
class MainActivity : FlutterActivity() {
    private val routingChannel = "ir.abtin.navigator/native_routing"
    private val voskChannel = "ir.abtin.navigator/vosk"
    private val carChannel = "ir.abtin.navigator/car_projection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, routingChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEngineReady" -> result.success(false) // true when native .so is bundled
                    "route" -> result.success(null) // Dart A* fallback
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, voskChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isModelReady" -> result.success(false) // place model under assets/vosk
                    "start", "stop" -> result.success(null)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, carChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "registerNavigationApp" -> result.success(null)
                    "pushManeuver" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleNavIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNavIntent(intent)
    }

    private fun handleNavIntent(intent: Intent?) {
        val data: Uri = intent?.data ?: return
        // Deep links are also parsed on Dart side via DeeplinkParser.
        // Keep hook for Android Auto / external apps.
    }
}
