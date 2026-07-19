package br.com.jeffersont.memoshot

import java.util.concurrent.atomic.AtomicBoolean

internal object FlutterEngineRuntimeState {
    private val uiEngineAttached = AtomicBoolean(false)
    private val activityVisible = AtomicBoolean(false)

    fun attachUiEngine() {
        uiEngineAttached.set(true)
    }

    fun detachUiEngine() {
        uiEngineAttached.set(false)
        activityVisible.set(false)
    }

    fun isUiEngineAttached(): Boolean = uiEngineAttached.get()

    fun resumeActivity() {
        activityVisible.set(true)
    }

    fun pauseActivity() {
        activityVisible.set(false)
    }

    fun isActivityVisible(): Boolean = activityVisible.get()
}
