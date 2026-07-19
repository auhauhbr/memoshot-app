package br.com.jeffersont.memoshot

import android.content.Intent
import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var screenshotBridge: ScreenshotMediaStoreBridge? = null
    private var preferencesBridge: AppPreferencesBridge? = null
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
        cancelLegacyReviewNotification()
        consumeLegacyReviewIntent(intent)
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
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeLegacyReviewIntent(intent)
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

    private fun cancelLegacyReviewNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(ReviewNotificationPolicy.NOTIFICATION_ID)
        ReviewNotificationState(applicationContext).apply {
            setEnabled(false)
            clearQueueMarkers()
        }
    }

    private fun consumeLegacyReviewIntent(intent: Intent?) {
        if (intent?.action != ReviewNotificationBridge.ACTION_OPEN_REVIEW_QUEUE) return
        intent.removeExtra(ReviewNotificationBridge.EXTRA_DESTINATION)
        intent.action = null
    }
}
