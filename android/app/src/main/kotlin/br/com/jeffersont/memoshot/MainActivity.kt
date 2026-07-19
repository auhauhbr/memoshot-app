package br.com.jeffersont.memoshot

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var screenshotBridge: ScreenshotMediaStoreBridge? = null
    private var preferencesBridge: AppPreferencesBridge? = null
    private var reviewNotificationBridge: ReviewNotificationBridge? = null
    private var reviewNavigationBridge: ReviewNavigationBridge? = null
    private var existingScreenshotScannerBridge: ExistingScreenshotScannerBridge? = null
    private var mediaStoreContentBridge: MediaStoreContentBridge? = null

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
        reviewNotificationBridge = ReviewNotificationBridge(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            activity = this,
        )
        reviewNavigationBridge = ReviewNavigationBridge(
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            initialIntent = intent,
        )
        existingScreenshotScannerBridge = ExistingScreenshotScannerBridge(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        mediaStoreContentBridge = MediaStoreContentBridge(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onResume() {
        super.onResume()
        FlutterEngineRuntimeState.resumeActivity()
    }

    override fun onPause() {
        FlutterEngineRuntimeState.pauseActivity()
        reviewNotificationBridge?.publishDeferredIfNeeded()
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        reviewNavigationBridge?.handleIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (screenshotBridge?.onRequestPermissionsResult(requestCode) == true) return
        if (reviewNotificationBridge?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        screenshotBridge?.dispose()
        screenshotBridge = null
        preferencesBridge?.dispose()
        preferencesBridge = null
        reviewNotificationBridge?.dispose()
        reviewNotificationBridge = null
        reviewNavigationBridge?.dispose()
        reviewNavigationBridge = null
        existingScreenshotScannerBridge?.dispose()
        existingScreenshotScannerBridge = null
        mediaStoreContentBridge?.dispose()
        mediaStoreContentBridge = null
        FlutterEngineRuntimeState.detachUiEngine()
        val processingScheduler = BackgroundProcessingScheduler(applicationContext)
        processingScheduler.enqueueIfEnabled()
        if (AppPreferencesBridge.isHistoricalPreparationActive(applicationContext)) {
            processingScheduler.enqueueHistoricalPreparation()
        }
        super.onDestroy()
    }
}
