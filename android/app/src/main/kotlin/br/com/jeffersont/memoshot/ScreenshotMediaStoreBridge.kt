package br.com.jeffersont.memoshot

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

internal class ScreenshotMediaStoreBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(messenger, METHODS_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENTS_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val preferences = activity.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    private val monitorState = NativeScreenshotMonitorState(activity)
    private val backgroundScheduler = ScreenshotBackgroundScheduler(activity)
    private val backgroundInboxHandler = BackgroundScreenshotInboxHandler(activity)
    private var permissionResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null
    private var observer: ContentObserver? = null
    private var observerThread: HandlerThread? = null
    private var observerHandler: Handler? = null
    private val observerEvent = Runnable { mainHandler.post { eventSink?.success(null) } }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        executor.execute { cleanupStaleTemporaryFiles() }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (backgroundInboxHandler.handle(call, result)) return
        when (call.method) {
            "permissionStatus" -> result.success(permissionStatus())
            "requestPermission" -> requestPermission(result)
            "openAppSettings" -> {
                openAppSettings()
                result.success(null)
            }
            "currentMaxMediaId" -> runInBackground(result) { currentMaxMediaId() }
            "scanAfter" -> {
                val marker = call.argument<Number>("lastMediaId")?.toLong() ?: 0L
                runInBackground(result) { scanAfter(marker) }
            }
            "startObserving" -> {
                startObserving()
                result.success(null)
            }
            "stopObserving" -> {
                stopObserving()
                result.success(null)
            }
            "deleteTemporary" -> {
                val path = call.argument<String>("path")
                if (path != null) deleteTemporary(path)
                result.success(null)
            }
            "configureBackgroundMonitoring" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                val marker = call.argument<Number>("lastMediaId")?.toLong() ?: 0L
                val resetBaseline = call.argument<Boolean>("resetBaseline") == true
                configureBackgroundMonitoring(enabled, marker, resetBaseline, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun configureBackgroundMonitoring(
        enabled: Boolean,
        marker: Long,
        resetBaseline: Boolean,
        result: MethodChannel.Result,
    ) {
        if (!enabled) {
            backgroundScheduler.cancel()
            result.success(backgroundStatus())
            return
        }
        if (permissionStatus() != "fullAccess") {
            backgroundScheduler.cancel()
            result.success(backgroundStatus())
            return
        }
        val available = if (resetBaseline) {
            backgroundScheduler.activate(marker)
        } else {
            backgroundScheduler.reconcile(marker)
        }
        result.success(
            mapOf(
                "available" to available,
                "enabled" to monitorState.isEnabled(),
                "lastMediaId" to monitorState.marker(),
            ),
        )
    }

    private fun backgroundStatus(): Map<String, Any> = mapOf(
        "available" to backgroundScheduler.isAvailable(),
        "enabled" to monitorState.isEnabled(),
        "lastMediaId" to monitorState.marker(),
    )

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopObserving()
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val pending = permissionResult ?: return true
        permissionResult = null
        mainHandler.post { pending.success(permissionStatus()) }
        return true
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success("fullAccess")
            return
        }
        if (permissionStatus() == "fullAccess") {
            result.success("fullAccess")
            return
        }
        if (permissionResult != null) {
            result.error("request_in_progress", "Solicitação já está em andamento.", null)
            return
        }
        permissionResult = result
        preferences.edit().putBoolean(KEY_PERMISSION_REQUESTED, true).apply()
        val permissions = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                arrayOf(Manifest.permission.READ_MEDIA_IMAGES)
            else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        ActivityCompat.requestPermissions(activity, permissions, PERMISSION_REQUEST)
    }

    private fun permissionStatus(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return "fullAccess"
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        if (ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED) {
            return "fullAccess"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return "limitedAccess"
        }
        if (!preferences.getBoolean(KEY_PERMISSION_REQUESTED, false)) return "notRequested"
        return if (ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)) {
            "denied"
        } else {
            "permanentlyDenied"
        }
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    private fun currentMaxMediaId(): Long {
        ensureFullAccess()
        val projection = arrayOf(MediaStore.Images.Media._ID)
        activity.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            "${MediaStore.Images.Media._ID} DESC",
        )?.use { cursor ->
            return if (cursor.moveToFirst()) cursor.getLong(0) else 0L
        }
        return 0L
    }

    private fun scanAfter(lastMediaId: Long): Map<String, Any> {
        ensureFullAccess()
        var lastExamined = lastMediaId
        var rejectedCount = 0
        val items = mutableListOf<Map<String, Any?>>()
        val projection = mutableListOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.MIME_TYPE,
            MediaStore.Images.Media.DATE_ADDED,
            MediaStore.Images.Media.DATE_TAKEN,
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(MediaStore.Images.Media.RELATIVE_PATH)
                add(MediaStore.Images.Media.IS_PENDING)
            }
        }.toTypedArray()
        val selection = "${MediaStore.Images.Media._ID} > ?"
        val selectionArgs = arrayOf(lastMediaId.toString())
        activity.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${MediaStore.Images.Media._ID} ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
            val addedIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
            val takenIndex = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)
            val pathIndex = cursor.getColumnIndex(MediaStore.Images.Media.RELATIVE_PATH)
            val pendingIndex = cursor.getColumnIndex(MediaStore.Images.Media.IS_PENDING)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIndex)
                if (pendingIndex >= 0 && cursor.getInt(pendingIndex) != 0) {
                    // Não ultrapassa um arquivo ainda em gravação; ele será
                    // reavaliado pelo próximo evento ou retomada.
                    break
                }
                lastExamined = id
                val mimeType = cursor.getString(mimeIndex)
                val displayName = cursor.getString(nameIndex).orEmpty()
                val relativePath = if (pathIndex >= 0) cursor.getString(pathIndex).orEmpty() else ""
                if (!ScreenshotRecognition.isScreenshot(
                        mimeType,
                        relativePath,
                        null,
                        displayName,
                    )
                ) continue
                val temporary = copyToPrivateCache(id, mimeType)
                if (temporary == null) {
                    rejectedCount++
                    continue
                }
                items += mapOf(
                    "mediaId" to id,
                    "temporaryPath" to temporary.absolutePath,
                    "mimeType" to mimeType,
                    "capturedAt" to MediaStoreCaptureTime.resolve(
                        cursor.getLong(takenIndex),
                        cursor.getLong(addedIndex),
                    ),
                )
            }
        }
        return mapOf(
            "lastExaminedMediaId" to lastExamined,
            "items" to items,
            "rejectedCount" to rejectedCount,
        )
    }

    private fun copyToPrivateCache(id: Long, mimeType: String?): File? {
        val directory = File(activity.cacheDir, CACHE_DIRECTORY).apply { mkdirs() }
        val suffix = when (mimeType) {
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            else -> ".jpg"
        }
        val target = File(directory, "automatic_${id}_${UUID.randomUUID()}$suffix")
        val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
        return try {
            activity.contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            target
        } catch (_: Exception) {
            target.delete()
            null
        }
    }

    private fun deleteTemporary(path: String) {
        val cacheRoot = File(activity.cacheDir, CACHE_DIRECTORY).canonicalFile
        val candidate = File(path).canonicalFile
        if (candidate.parentFile == cacheRoot) candidate.delete()
    }

    private fun cleanupStaleTemporaryFiles() {
        val directory = File(activity.cacheDir, CACHE_DIRECTORY)
        val cutoff = System.currentTimeMillis() - STALE_TEMPORARY_MS
        directory.listFiles()?.forEach { file ->
            if (file.isFile && file.lastModified() < cutoff) file.delete()
        }
    }

    private fun startObserving() {
        if (observer != null || permissionStatus() != "fullAccess") return
        val thread = HandlerThread("memoshot-media-observer").also { it.start() }
        val handler = Handler(thread.looper)
        val contentObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                handler.removeCallbacks(observerEvent)
                handler.postDelayed(observerEvent, OBSERVER_DEBOUNCE_MS)
            }
        }
        activity.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            contentObserver,
        )
        observerThread = thread
        observerHandler = handler
        observer = contentObserver
    }

    private fun stopObserving() {
        observer?.let { activity.contentResolver.unregisterContentObserver(it) }
        observerHandler?.removeCallbacksAndMessages(null)
        observerThread?.quitSafely()
        observer = null
        observerHandler = null
        observerThread = null
    }

    private fun ensureFullAccess() {
        check(permissionStatus() == "fullAccess") { "Acesso às imagens indisponível." }
    }

    private fun runInBackground(result: MethodChannel.Result, block: () -> Any) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (_: Exception) {
                mainHandler.post {
                    result.error("media_store_unavailable", "Verificação indisponível.", null)
                }
            }
        }
    }

    fun dispose() {
        stopObserving()
        permissionResult = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        backgroundInboxHandler.dispose()
        executor.shutdownNow()
    }

    companion object {
        private const val METHODS_CHANNEL = AUTOMATIC_SCREENSHOTS_METHODS_CHANNEL
        private const val EVENTS_CHANNEL =
            "br.com.jeffersont.memoshot/automatic_screenshots/events"
        private const val PREFERENCES = "automatic_screenshot_permission"
        private const val KEY_PERMISSION_REQUESTED = "requested"
        private const val CACHE_DIRECTORY = "automatic_screenshots"
        private const val PERMISSION_REQUEST = 5202
        private const val OBSERVER_DEBOUNCE_MS = 650L
        private const val STALE_TEMPORARY_MS = 24L * 60 * 60 * 1000
    }
}
