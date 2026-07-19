package br.com.jeffersont.memoshot

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class ReviewNotificationBridge(
    context: Context,
    messenger: BinaryMessenger,
    private val activity: Activity? = null,
) : MethodChannel.MethodCallHandler {
    private val applicationContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val state = ReviewNotificationState(applicationContext)
    private val notificationManager =
        applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(statePayload())
            "requestPermissionAndEnable" -> requestPermissionAndEnable(result)
            "disable" -> {
                state.setEnabled(false)
                cancelNotification(clearMarkers = true)
                result.success(null)
            }
            "dismissPrompt" -> {
                state.markPromptHandled()
                result.success(null)
            }
            "openAndroidSettings" -> openAndroidSettings(result)
            "synchronize" -> {
                val count = call.argument<Int>("pendingCount") ?: 0
                val marker = call.argument<String>("marker").orEmpty()
                synchronize(count, marker)
                result.success(null)
            }
            "cancel" -> {
                cancelNotification(clearMarkers = true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_NOTIFICATIONS) return false
        state.markPromptHandled()
        val granted = hasPermission()
        state.setEnabled(granted)
        pendingPermissionResult?.success(statePayload())
        pendingPermissionResult = null
        return true
    }

    fun publishDeferredIfNeeded() {
        if (!state.isEnabled() || !hasPermission()) return
        val count = state.currentCount()
        val marker = state.currentMarker().orEmpty()
        if (count <= 0 || marker.isEmpty()) return
        val shouldAlert = ReviewNotificationPolicy.shouldAlert(
            pendingCount = count,
            marker = marker,
            lastCount = state.lastCount(),
            lastMarker = state.lastMarker(),
            activityVisible = false,
        )
        if (shouldAlert) publish(count, marker, true)
    }

    fun dispose() {
        pendingPermissionResult?.error("activityDisposed", null, null)
        pendingPermissionResult = null
        channel.setMethodCallHandler(null)
    }

    private fun requestPermissionAndEnable(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || hasPermission()) {
            state.markPromptHandled()
            state.setEnabled(true)
            ensureChannel()
            result.success(statePayload())
            return
        }
        val currentActivity = activity
        if (currentActivity == null || pendingPermissionResult != null) {
            result.success(statePayload())
            return
        }
        state.markPromptHandled()
        pendingPermissionResult = result
        currentActivity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS,
        )
    }

    private fun openAndroidSettings(result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("activityUnavailable", null, null)
            return
        }
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            data = Uri.parse("package:${applicationContext.packageName}")
            putExtra(Settings.EXTRA_APP_PACKAGE, applicationContext.packageName)
        }
        currentActivity.startActivity(intent)
        result.success(null)
    }

    private fun synchronize(pendingCount: Int, marker: String) {
        if (!state.isEnabled() || !hasPermission()) return
        if (pendingCount <= 0 || marker.isEmpty()) {
            cancelNotification(clearMarkers = true)
            return
        }
        ensureChannel()
        if (isChannelBlocked()) return
        state.storeCurrent(pendingCount, marker)
        val lastCount = state.lastCount()
        val lastMarker = state.lastMarker()
        if (pendingCount == lastCount && marker == lastMarker) return
        val visible = FlutterEngineRuntimeState.isActivityVisible()
        val shouldAlert = ReviewNotificationPolicy.shouldAlert(
            pendingCount,
            marker,
            lastCount,
            lastMarker,
            visible,
        )
        publish(pendingCount, marker, shouldAlert)
        if (!visible || pendingCount < lastCount) {
            state.storeNotified(pendingCount, marker)
        }
    }

    private fun publish(pendingCount: Int, marker: String, shouldAlert: Boolean) {
        val content = ReviewNotificationPolicy.content(pendingCount)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(applicationContext, ReviewNotificationPolicy.CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(applicationContext)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_review_notification)
            .setContentTitle(content.title)
            .setContentText(content.text)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setOnlyAlertOnce(!shouldAlert)
            .setContentIntent(reviewPendingIntent())
            .build()
        notificationManager.notify(ReviewNotificationPolicy.NOTIFICATION_ID, notification)
        if (shouldAlert) state.storeNotified(pendingCount, marker)
    }

    private fun reviewPendingIntent(): PendingIntent {
        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            action = ACTION_OPEN_REVIEW_QUEUE
            putExtra(EXTRA_DESTINATION, ReviewNotificationPolicy.DESTINATION_REVIEW_QUEUE)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            applicationContext,
            ReviewNotificationPolicy.NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (notificationManager.getNotificationChannel(ReviewNotificationPolicy.CHANNEL_ID) != null) {
            return
        }
        val notificationChannel = NotificationChannel(
            ReviewNotificationPolicy.CHANNEL_ID,
            "Revisões do MemoShot",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Avisos sobre prints que precisam de confirmação."
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(notificationChannel)
    }

    private fun cancelNotification(clearMarkers: Boolean) {
        notificationManager.cancel(ReviewNotificationPolicy.NOTIFICATION_ID)
        if (clearMarkers) state.clearQueueMarkers()
    }

    private fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            applicationContext.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    private fun isChannelBlocked(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            notificationManager.getNotificationChannel(ReviewNotificationPolicy.CHANNEL_ID)
                ?.importance == NotificationManager.IMPORTANCE_NONE

    private fun permissionName(): String {
        if (hasPermission() && !isChannelBlocked() && notificationManager.areNotificationsEnabled()) {
            return "granted"
        }
        if (!state.isPromptHandled()) return "denied"
        val currentActivity = activity
        val blocked = isChannelBlocked() || !notificationManager.areNotificationsEnabled() ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                currentActivity != null &&
                !currentActivity.shouldShowRequestPermissionRationale(
                    Manifest.permission.POST_NOTIFICATIONS,
                ))
        return if (blocked) "blocked" else "denied"
    }

    private fun statePayload(): Map<String, Any> = mapOf(
        "enabled" to state.isEnabled(),
        "promptHandled" to state.isPromptHandled(),
        "permission" to permissionName(),
    )

    companion object {
        const val CHANNEL = "br.com.jeffersont.memoshot/review_notifications"
        const val ACTION_OPEN_REVIEW_QUEUE =
            "br.com.jeffersont.memoshot.action.OPEN_REVIEW_QUEUE"
        const val EXTRA_DESTINATION = "memoshot_destination"
        private const val REQUEST_NOTIFICATIONS = 9503
    }
}
