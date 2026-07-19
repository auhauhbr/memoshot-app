package br.com.jeffersont.memoshot

import java.util.concurrent.atomic.AtomicBoolean

internal object FlutterEngineRuntimeState {
    private val uiEngineAttached = AtomicBoolean(false)

    fun attachUiEngine() {
        uiEngineAttached.set(true)
    }

    fun detachUiEngine() {
        uiEngineAttached.set(false)
    }

    fun isUiEngineAttached(): Boolean = uiEngineAttached.get()
}
