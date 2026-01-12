package com.unifiedplayer

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import android.util.Log
import com.facebook.react.bridge.UiThreadUtil
import android.view.View
import android.os.Environment
import java.io.File

class UnifiedPlayerModule(private val reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    companion object {
        private const val TAG = "UnifiedPlayerModule"
    }

    override fun getName(): String = "UnifiedPlayer"

    private fun getPlayerViewByTag(viewTag: Int): UnifiedPlayerView? {
        return try {
            val view = reactApplicationContext.currentActivity?.findViewById<View>(viewTag)
            (view as? UnifiedPlayerView) ?: run {
                if (view != null) {
                    Log.e(TAG, "View with tag $viewTag is not a UnifiedPlayerView")
                }
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding view: ${e.message}")
            null
        }
    }

    /**
     * Helper function to execute operations on the player view.
     * Eliminates repetitive boilerplate across all methods.
     */
    private inline fun <T> executeOnPlayerView(
        viewTag: Int,
        promise: Promise,
        errorCode: String,
        crossinline action: (UnifiedPlayerView) -> T
    ) {
        try {
            val playerView = getPlayerViewByTag(viewTag)
            if (playerView != null) {
                UiThreadUtil.runOnUiThread {
                    try {
                        val result = action(playerView)
                        promise.resolve(result)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error during $errorCode: ${e.message}")
                        promise.reject(errorCode, e.message, e)
                    }
                }
            } else {
                promise.reject("VIEW_NOT_FOUND", "Player view not found for tag: $viewTag")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in $errorCode: ${e.message}")
            promise.reject(errorCode, e.message, e)
        }
    }

    @ReactMethod
    fun play(viewTag: Int, promise: Promise) = executeOnPlayerView(viewTag, promise, "PLAY_ERROR") {
        it.play()
        true
    }

    @ReactMethod
    fun pause(viewTag: Int, promise: Promise) = executeOnPlayerView(viewTag, promise, "PAUSE_ERROR") {
        it.pause()
        true
    }

    @ReactMethod
    fun seekTo(viewTag: Int, seconds: Float, promise: Promise) = executeOnPlayerView(viewTag, promise, "SEEK_ERROR") {
        it.seekTo(seconds)
        true
    }

    @ReactMethod
    fun getCurrentTime(viewTag: Int, promise: Promise) = executeOnPlayerView(viewTag, promise, "GET_TIME_ERROR") {
        it.getCurrentTime()
    }

    @ReactMethod
    fun getDuration(viewTag: Int, promise: Promise) = executeOnPlayerView(viewTag, promise, "GET_DURATION_ERROR") {
        it.getDuration()
    }

    @ReactMethod
    fun capture(viewTag: Int, promise: Promise) = executeOnPlayerView(viewTag, promise, "CAPTURE_ERROR") {
        it.capture()
    }

    /**
     * Start recording/downloading the video.
     * Note: This downloads the source video file rather than recording the rendered video.
     */
    @ReactMethod
    fun startRecording(viewTag: Int, outputPath: String?, promise: Promise) = executeOnPlayerView(viewTag, promise, "RECORDING_ERROR") {
        val finalOutputPath = if (outputPath.isNullOrEmpty()) {
            val moviesDir = File(reactApplicationContext.getExternalFilesDir(Environment.DIRECTORY_MOVIES), "recordings")
            if (!moviesDir.exists()) moviesDir.mkdirs()
            File(moviesDir, "recording_${System.currentTimeMillis()}.mp4").absolutePath
        } else {
            outputPath
        }
        it.startRecording(finalOutputPath)
    }

    @ReactMethod
    fun toggleFullscreen(viewTag: Int, isFullscreen: Boolean, promise: Promise) = executeOnPlayerView(viewTag, promise, "FULLSCREEN_ERROR") {
        it.setIsFullscreen(isFullscreen)
        true
    }

    @ReactMethod
    fun stopRecording(viewTag: Int, promise: Promise) = executeOnPlayerView(viewTag, promise, "RECORDING_ERROR") {
        it.stopRecording()
    }
}
