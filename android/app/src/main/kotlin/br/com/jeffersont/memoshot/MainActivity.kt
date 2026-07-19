package br.com.jeffersont.memoshot

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var screenshotBridge: ScreenshotMediaStoreBridge? = null
    private var preferencesBridge: AppPreferencesBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineRuntimeState.attachUiEngine()
        screenshotBridge = ScreenshotMediaStoreBridge(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        preferencesBridge = AppPreferencesBridge(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (screenshotBridge?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        screenshotBridge?.dispose()
        screenshotBridge = null
        preferencesBridge?.dispose()
        preferencesBridge = null
        FlutterEngineRuntimeState.detachUiEngine()
        BackgroundProcessingScheduler(applicationContext).enqueueIfEnabled()
        super.onDestroy()
    }
}
