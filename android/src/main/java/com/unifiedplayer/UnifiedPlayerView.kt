package com.unifiedplayer

import android.content.Context
import android.app.Activity
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.Color
import android.util.Base64
import java.io.ByteArrayOutputStream
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import com.bumptech.glide.Glide
import com.bumptech.glide.request.RequestOptions
import com.facebook.react.bridge.Arguments
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.PlaybackException
import com.google.android.exoplayer2.Tracks
import com.google.android.exoplayer2.video.VideoSize
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.events.RCTEventEmitter
import java.io.File
import android.os.Environment
import android.view.ViewGroup
import android.view.WindowManager
import android.os.Build
import android.view.Gravity
import android.widget.Button
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue

class UnifiedPlayerView(context: Context) : FrameLayout(context) {
    companion object {
        private const val TAG = "UnifiedPlayerView"

        // Event type constants
        const val EVENT_LOAD_START = "onLoadStart"
        const val EVENT_READY = "onReadyToPlay"
        const val EVENT_ERROR = "onError"
        const val EVENT_PROGRESS = "onProgress"
        const val EVENT_COMPLETE = "onPlaybackComplete"
        const val EVENT_STALLED = "onPlaybackStalled"
        const val EVENT_RESUMED = "onPlaybackResumed"
        const val EVENT_PLAYING = "onPlaying"
        const val EVENT_PAUSED = "onPaused"
        const val EVENT_FULLSCREEN_CHANGED = "onFullscreenChanged"
    }

    // Recording state (Note: "recording" actually downloads the source file, not screen recording)
    private var isRecording = false
    private var outputPath: String? = null

    // Player state
    private var videoUrl: String? = null
    private var thumbnailUrl: String? = null
    private var autoplay: Boolean = true
    private var loop: Boolean = false
    private var speed: Float = 1.0f // Default playback speed
    private var textureView: android.view.TextureView
    private var thumbnailImageView: ImageView? = null
    internal var player: ExoPlayer? = null
    private var currentProgress = 0
    private var isPaused = false
    private var isFullscreen = false
    private var originalOrientation: Int = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    private var originalSystemUiVisibility: Int = 0
    private var originalLayoutParams: ViewGroup.LayoutParams? = null
    private var originalParent: ViewGroup? = null
    private var originalIndex: Int = 0
    private var fullscreenContainer: FrameLayout? = null
    private var closeButton: Button? = null
    private var isTransitioningFullscreen = false // Flag to prevent player release during fullscreen transition

    private val progressHandler = Handler(Looper.getMainLooper())
    private val progressRunnable: Runnable = object : Runnable {
        override fun run() {
            player?.let {
                val currentTime = it.currentPosition.toFloat() / 1000f
                val duration = it.duration.toFloat() / 1000f

                // Log the actual values for debugging
                // Log.d(TAG, "Progress values - currentTime: $currentTime, duration: $duration, raw duration: ${it.duration}")

                // Only send valid duration values
                if (it.duration > 0) {
                    val event = Arguments.createMap()
                    event.putDouble("currentTime", currentTime.toDouble())
                    event.putDouble("duration", duration.toDouble())
                    
                    // Log.d(TAG, "Sending progress event: currentTime=$currentTime, duration=$duration")
                    sendEvent(EVENT_PROGRESS, event)
                } else {
                    // Log.d(TAG, "Not sending progress event because duration is $duration (raw: ${it.duration})")
                }
            } ?: Log.e(TAG, "Cannot send progress event: player is null")
            
            // Schedule the next update
            progressHandler.postDelayed(this, 250) // Update every 250ms
        }
    }

    init {
        setBackgroundColor(Color.BLACK)

        // Create ExoPlayer
        player = ExoPlayer.Builder(context).build()

        // Create TextureView for video rendering
        textureView = android.view.TextureView(context).apply {
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
        }

        // Create ImageView for thumbnail
        thumbnailImageView = ImageView(context).apply {
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
            scaleType = ImageView.ScaleType.CENTER_CROP
            visibility = View.GONE
        }

        // Add views to the layout (thumbnail on top of TextureView)
        addView(textureView)
        addView(thumbnailImageView)

    // We'll set the video surface when the TextureView's surface is available
    // in the onSurfaceTextureAvailable callback
    Log.d(TAG, "TextureView added to view hierarchy")
        // Log dimensions of the view
        post {
            Log.d(TAG, "UnifiedPlayerView dimensions after init: width=${width}, height=${height}")
        }

        player?.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                Log.d(TAG, "onPlaybackStateChanged: $playbackState")
                when (playbackState) {
                    Player.STATE_READY -> {
                        Log.d(TAG, "ExoPlayer STATE_READY")
                        // Ensure thumbnail is hidden when ready (might be needed if autoplay=false)
                        if (player?.isPlaying == false) { // Check if not already playing
                             thumbnailImageView?.visibility = View.GONE
                        }
                        sendEvent(EVENT_READY, Arguments.createMap())
                        // Start progress updates when ready
                        startProgressUpdates()
                    }
                    Player.STATE_ENDED -> {
                        Log.d(TAG, "ExoPlayer STATE_ENDED, loop: $loop, repeatMode: ${player?.repeatMode}")
                        // ExoPlayer handles looping via repeatMode, but we still need to check
                        // Only send completion event if not looping
                        if (!loop && player?.repeatMode != Player.REPEAT_MODE_ONE) {
                            Log.d(TAG, "Sending playback complete event")
                            sendEvent(EVENT_COMPLETE, Arguments.createMap())
                        } else {
                            Log.d(TAG, "Looping enabled, not sending completion event")
                            // Ensure playback speed is preserved after loop
                            if (speed != 1.0f && player != null) {
                                player?.setPlaybackSpeed(speed)
                                Log.d(TAG, "Restored playback speed: $speed after loop")
                            }
                        }
                    }
                    Player.STATE_BUFFERING -> {
                        Log.d(TAG, "ExoPlayer STATE_BUFFERING")
                        sendEvent(EVENT_STALLED, Arguments.createMap())
                    }
                    Player.STATE_IDLE -> {
                        Log.d(TAG, "ExoPlayer STATE_IDLE")
                    }
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                Log.d(TAG, "onIsPlayingChanged: $isPlaying") // Added log
                if (isPlaying) {
                    Log.d(TAG, "ExoPlayer is now playing")
                    // Hide thumbnail when video starts playing
                    thumbnailImageView?.visibility = View.GONE
                    // Ensure playback speed is preserved when playback resumes (e.g., after loop)
                    if (speed != 1.0f) {
                        player?.setPlaybackSpeed(speed)
                        Log.d(TAG, "Restored playback speed: $speed when playback resumed")
                    }
                    sendEvent(EVENT_RESUMED, Arguments.createMap())
                    sendEvent(EVENT_PLAYING, Arguments.createMap())
                } else {
                    Log.d(TAG, "ExoPlayer is now paused")
                    sendEvent(EVENT_PAUSED, Arguments.createMap())
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                Log.e(TAG, "ExoPlayer error: $error")
                val event = Arguments.createMap()
                event.putString("code", "PLAYBACK_ERROR")
                event.putString("message", error.message ?: "Unknown playback error")
                sendEvent(EVENT_ERROR, event)
            }

            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                Log.d(TAG, "onMediaItemTransition with reason: $reason")
                sendEvent(EVENT_LOAD_START, Arguments.createMap())
            }

            override fun onPlaybackSuppressionReasonChanged(playbackSuppressionReason: Int) {
                // Called when playback is suppressed temporarily due to content restrictions.
                Log.d(TAG, "ExoPlayer onPlaybackSuppressionReasonChanged: $playbackSuppressionReason")
            }

            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                // Called when playWhenReady state changes.
                Log.d(TAG, "ExoPlayer onPlayWhenReadyChanged: playWhenReady=$playWhenReady, reason=$reason")
            }

            override fun onPositionDiscontinuity(reason: Int) {
                 // Called when there's a discontinuity in playback, such as seeking or ad insertion.
                 Log.d(TAG, "ExoPlayer onPositionDiscontinuity: reason=$reason")
            }

            override fun onRepeatModeChanged(repeatMode: Int) {
                // Called when the repeat mode changes.
                Log.d(TAG, "ExoPlayer onRepeatModeChanged: repeatMode=$repeatMode")
            }

            override fun onShuffleModeEnabledChanged(shuffleModeEnabled: Boolean) {
                // Called when shuffle mode is enabled or disabled.
                Log.d(TAG, "ExoPlayer onShuffleModeEnabledChanged: shuffleModeEnabled=$shuffleModeEnabled")
            }

            override fun onTracksChanged(tracks: Tracks) {
                // Called when available tracks change.
                Log.d(TAG, "ExoPlayer onTracksChanged: tracks=$tracks")
            }

            override fun onVolumeChanged(volume: Float) {
                // Called when volume changes.
                Log.d(TAG, "ExoPlayer onVolumeChanged: volume=$volume")
            }

            override fun onVideoSizeChanged(videoSize: VideoSize) {
                // Handle video size changes if needed
            }
        })
    }

    // Helper function to load and prepare a video URL
    private fun loadVideoSource(url: String) {
        Log.d(TAG, "Loading video source: $url")
        try {
            val mediaItem = MediaItem.fromUri(url)
            player?.stop()
            player?.clearMediaItems()
            player?.setMediaItem(mediaItem)
            player?.prepare()
            player?.playWhenReady = autoplay && !isPaused
            player?.repeatMode = if (loop) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
            // Apply playback speed if set
            if (speed != 1.0f) {
                player?.setPlaybackSpeed(speed)
            }

            Log.d(TAG, "ExoPlayer configured with URL: $url, autoplay: $autoplay, loop: $loop, isPaused: $isPaused, speed: $speed")
            sendEvent(EVENT_LOAD_START, Arguments.createMap())

        } catch (e: Exception) {
            Log.e(TAG, "Error setting video source: ${e.message}", e)
            val event = Arguments.createMap()
            event.putString("code", "SOURCE_ERROR")
            event.putString("message", "Failed to load video source: $url")
            sendEvent(EVENT_ERROR, event)
        }
    }

    fun setVideoUrl(url: String?) {
        Log.d(TAG, "Setting video URL: $url")
        if (url != null && url.isNotEmpty()) {
            videoUrl = url
            loadVideoSource(url)
        } else {
            Log.w(TAG, "Received null or empty URL")
            player?.stop()
            player?.clearMediaItems()
            videoUrl = null
        }
    }

    fun setAutoplay(value: Boolean) {
        autoplay = value
        player?.playWhenReady = value
    }

    fun setLoop(value: Boolean) {
        Log.d(TAG, "Setting loop to: $value")
        loop = value
        player?.repeatMode = if (loop) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
    }

    fun setThumbnailUrl(url: String?) {
        Log.d(TAG, "Setting thumbnail URL: $url")
        
        thumbnailUrl = url
        
        if (url != null && url.isNotEmpty()) {
            // Show the thumbnail ImageView
            thumbnailImageView?.visibility = View.VISIBLE
            
            // Load the thumbnail image using Glide
            try {
                Glide.with(context)
                    .load(url)
                    .apply(RequestOptions().centerCrop())
                    .into(thumbnailImageView!!)
                
                Log.d(TAG, "Thumbnail image loading started")
            } catch (e: Exception) {
                Log.e(TAG, "Error loading thumbnail image: ${e.message}", e)
                thumbnailImageView?.visibility = View.GONE
            }
        } else {
            // Hide the thumbnail if URL is null or empty
            thumbnailImageView?.visibility = View.GONE
        }
    }

    fun setIsPaused(isPaused: Boolean) {
        Log.d(TAG, "setIsPaused called with value: $isPaused")
        this.isPaused = isPaused
        if (isPaused) {
            player?.pause()
        } else {
            player?.play()
        }
    }

    fun setIsFullscreen(fullscreen: Boolean) {
        Log.d(TAG, "setIsFullscreen called with value: $fullscreen")
        if (this.isFullscreen == fullscreen) {
            return // Already in the requested state
        }

        this.isFullscreen = fullscreen
        val reactContext = context as? ReactContext ?: return
        val activity = reactContext.currentActivity ?: return

        // Alternative approach: Override the manifest setting temporarily
        if (fullscreen) {
            // Clear any portrait lock from manifest before entering fullscreen
            overrideOrientationRestrictions(activity, true)
            enterFullscreen(activity)
        } else {
            exitFullscreen(activity)
            // Restore portrait lock after exiting fullscreen
            overrideOrientationRestrictions(activity, false)
        }

        // Send event about fullscreen state change
        val event = Arguments.createMap()
        event.putBoolean("isFullscreen", fullscreen)
        sendEvent(EVENT_FULLSCREEN_CHANGED, event)
    }

    /**
     * Override orientation restrictions from manifest
     * This is a workaround for when android:screenOrientation="portrait" is set in manifest
     */
    private fun overrideOrientationRestrictions(activity: Activity, enableLandscape: Boolean) {
        try {
            if (enableLandscape) {
                // First set to unspecified to clear any manifest restrictions
                activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                // Small delay to ensure the change takes effect
                Handler(Looper.getMainLooper()).postDelayed({
                    // Then set to sensor landscape
                    activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                }, 50)
            } else {
                // Restore portrait orientation
                activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to override orientation restrictions: ${e.message}")
        }
    }

    private fun enterFullscreen(activity: Activity) {
        Log.d(TAG, "Entering fullscreen mode")

        // Save current orientation
        originalOrientation = activity.requestedOrientation

        // Note: Orientation change is already handled by overrideOrientationRestrictions()
        // in setIsFullscreen() before this method is called

        // Hide system UI for fullscreen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.window.insetsController?.let { controller ->
                controller.hide(android.view.WindowInsets.Type.statusBars())
                controller.hide(android.view.WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            originalSystemUiVisibility = activity.window.decorView.systemUiVisibility
            @Suppress("DEPRECATION")
            activity.window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }

        // Add FLAG_KEEP_SCREEN_ON to prevent screen from turning off during playback
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Save original parent and layout params
        originalParent = parent as? ViewGroup
        originalLayoutParams = layoutParams
        originalIndex = originalParent?.indexOfChild(this) ?: 0

        // Set flag to prevent player release during transition
        isTransitioningFullscreen = true

        // Remove from current parent
        originalParent?.removeView(this)

        // Create fullscreen container
        fullscreenContainer = FrameLayout(context).apply {
            setBackgroundColor(Color.BLACK)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        // Add player to fullscreen container
        fullscreenContainer?.addView(this, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        // Create close button
        closeButton = Button(context).apply {
            text = "✕"
            textSize = 18f
            setTextColor(Color.WHITE)

            // Create circular background
            val drawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(128, 0, 0, 0)) // Semi-transparent black
            }
            background = drawable

            // Set button size (44dp x 44dp for touch target)
            val buttonSize = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 44f, resources.displayMetrics
            ).toInt()

            layoutParams = FrameLayout.LayoutParams(buttonSize, buttonSize).apply {
                gravity = Gravity.TOP or Gravity.END
                val margin = TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP, 16f, resources.displayMetrics
                ).toInt()
                setMargins(margin, margin, margin, margin)
            }

            setOnClickListener {
                setIsFullscreen(false)
            }
        }

        // Add close button to fullscreen container
        fullscreenContainer?.addView(closeButton)

        // Add fullscreen container to the decor view (root)
        val decorView = activity.window.decorView as? ViewGroup
        decorView?.addView(fullscreenContainer)

        // Reset transition flag
        isTransitioningFullscreen = false

        Log.d(TAG, "Fullscreen mode activated - player moved to fullscreen container")
    }

    private fun exitFullscreen(activity: Activity) {
        Log.d(TAG, "Exiting fullscreen mode")

        // Note: Orientation restoration is already handled by overrideOrientationRestrictions()
        // in setIsFullscreen() after this method is called

        // Restore system UI
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.window.insetsController?.let { controller ->
                controller.show(android.view.WindowInsets.Type.statusBars())
                controller.show(android.view.WindowInsets.Type.navigationBars())
            }
        } else {
            @Suppress("DEPRECATION")
            activity.window.decorView.systemUiVisibility = originalSystemUiVisibility
        }

        // Remove FLAG_KEEP_SCREEN_ON
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Set flag to prevent player release during transition
        isTransitioningFullscreen = true

        // Remove player from fullscreen container
        fullscreenContainer?.removeView(this)

        // Remove fullscreen container from decor view
        val decorView = activity.window.decorView as? ViewGroup
        fullscreenContainer?.let { container ->
            decorView?.removeView(container)
        }

        // Restore player to original parent
        originalParent?.let { parent ->
            // Add back at original index with original layout params
            originalLayoutParams?.let { params ->
                parent.addView(this, originalIndex.coerceAtMost(parent.childCount), params)
            } ?: parent.addView(this, originalIndex.coerceAtMost(parent.childCount))
        }

        // Reset transition flag
        isTransitioningFullscreen = false

        // Clean up references
        closeButton = null
        fullscreenContainer = null
        originalParent = null
        originalLayoutParams = null

        Log.d(TAG, "Fullscreen mode exited - player restored to original position")
    }

    fun play() {
        Log.d(TAG, "Play method called")
        player?.playWhenReady = true
        // Ensure playback speed is applied when playing
        if (speed != 1.0f) {
            player?.setPlaybackSpeed(speed)
        }
    }

    fun pause() {
        Log.d(TAG, "Pause method called")
        player?.playWhenReady = false
    }

    fun seekTo(seconds: Float) {
        Log.d(TAG, "SeekTo method called with seconds: $seconds")
        player?.let {
            val milliseconds = (seconds * 1000).toLong()
            Log.d(TAG, "Seeking to $milliseconds ms")
            it.seekTo(milliseconds)

            // Force a progress update after seeking
            progressRunnable.run()
        } ?: Log.e(TAG, "Cannot seek: player is null")
    }

    fun setSpeed(speedValue: Float) {
        Log.d(TAG, "SetSpeed method called with speed: $speedValue")
        speed = speedValue // Store the speed value
        player?.let {
            it.setPlaybackSpeed(speed)
            Log.d(TAG, "Playback speed set to: $speed")
        } ?: Log.e(TAG, "Cannot set speed: player is null")
    }

    fun getCurrentTime(): Float {
        Log.d(TAG, "GetCurrentTime method called")
        return player?.let {
            val currentTime = it.currentPosition.toFloat() / 1000f
            Log.d(TAG, "Current time: $currentTime seconds")
            currentTime
        } ?: run {
            Log.e(TAG, "Cannot get current time: player is null")
            0f
        }
    }

    fun getDuration(): Float {
        Log.d(TAG, "GetDuration method called")
        return player?.let {
            val duration = it.duration.toFloat() / 1000f
            Log.d(TAG, "Duration: $duration seconds (raw: ${it.duration})")
            if (it.duration > 0) duration else 0f
        } ?: run {
            Log.e(TAG, "Cannot get duration: player is null")
            0f
        }
    }

    // Add a getter for the ExoPlayer instance
    val exoPlayer: ExoPlayer?
        get() = this.player

    private fun sendEvent(eventName: String, params: WritableMap) {
        try {
            // Log the event for debugging
            // Log.d(TAG, "Sending direct event: $eventName with params: $params")
            
            // Map event names to their corresponding top event names
            val topEventName = when (eventName) {
                EVENT_READY -> "topReadyToPlay"
                EVENT_ERROR -> "topError"
                EVENT_PROGRESS -> "topProgress"
                EVENT_COMPLETE -> "topPlaybackComplete"
                EVENT_STALLED -> "topPlaybackStalled"
                EVENT_RESUMED -> "topPlaybackResumed"
                EVENT_PLAYING -> "topPlaying"
                EVENT_PAUSED -> "topPlaybackPaused"
                EVENT_LOAD_START -> "topLoadStart"
                EVENT_FULLSCREEN_CHANGED -> "topFullscreenChanged"
                else -> "top${eventName.substring(2)}" // Fallback for any other events
            }
            
            // Use the ReactContext to dispatch the event directly to the view
            val reactContext = context as ReactContext
            reactContext.getJSModule(RCTEventEmitter::class.java)
                .receiveEvent(id, topEventName, params)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending event $eventName: ${e.message}", e)
        }
    }
    
    // Method to explicitly start progress updates
    private fun startProgressUpdates() {
        // Only start if player is ready and has duration
        if (player?.playbackState == Player.STATE_READY && (player?.duration ?: 0) > 0) {
             Log.d(TAG, "Starting progress updates")
             progressHandler.removeCallbacks(progressRunnable) // Remove existing callbacks
             progressHandler.post(progressRunnable) // Post the runnable
        } else {
             Log.d(TAG, "Skipping progress updates start: Player not ready or duration is 0")
        }
    }

    // Method to stop progress updates
    private fun stopProgressUpdates() {
        Log.d(TAG, "Stopping progress updates")
        progressHandler.removeCallbacks(progressRunnable)
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val width = right - left
        val height = bottom - top
        Log.d(TAG, "UnifiedPlayerView onLayout: width=$width, height=$height")
        // Ensure textureView gets laid out properly
        textureView.layout(0, 0, width, height)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        Log.d(TAG, "UnifiedPlayerView onAttachedToWindow")
        textureView.surfaceTextureListener = object : android.view.TextureView.SurfaceTextureListener {
    override fun onSurfaceTextureAvailable(surface: android.graphics.SurfaceTexture, width: Int, height: Int) {
        Log.d(TAG, "TextureView onSurfaceTextureAvailable: width=$width, height=$height")
        // Create a Surface from the SurfaceTexture and set it on the player
        val videoSurface = android.view.Surface(surface)
        player?.setVideoSurface(videoSurface)
        Log.d(TAG, "Set video surface from TextureView's SurfaceTexture")
    }

    override fun onSurfaceTextureSizeChanged(surface: android.graphics.SurfaceTexture, width: Int, height: Int) {
        Log.d(TAG, "TextureView onSurfaceTextureSizeChanged: width=$width, height=$height")
    }

    override fun onSurfaceTextureDestroyed(surface: android.graphics.SurfaceTexture): Boolean {
        Log.d(TAG, "TextureView onSurfaceTextureDestroyed")
        // Set the player's surface to null to release it
        player?.setVideoSurface(null)
        Log.d(TAG, "Cleared video surface from player")
        return true
    }

    override fun onSurfaceTextureUpdated(surface: android.graphics.SurfaceTexture) {
        // This is called very frequently, so we'll comment out this log
        // Log.d(TAG, "TextureView onSurfaceTextureUpdated")
    }
}
        // Don't start progress updates here automatically, wait for STATE_READY
        // startProgressUpdates()
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        Log.d(TAG, "UnifiedPlayerView onDetachedFromWindow, isTransitioningFullscreen: $isTransitioningFullscreen")

        // Don't release player during fullscreen transitions
        if (isTransitioningFullscreen) {
            Log.d(TAG, "Skipping player release - fullscreen transition in progress")
            return
        }

        stopProgressUpdates() // Stop progress updates
        player?.release()
        player = null // Ensure player is nullified
        cleanupRecording() // Clean up recording resources if any
    }

    fun capture(): String {
        Log.d(TAG, "Capture method called")
        return try {
            player?.let { exoPlayer ->
                // Get the video size from the player
                val videoSize = exoPlayer.videoSize
                if (videoSize.width <= 0 || videoSize.height <= 0) {
                    Log.e(TAG, "Invalid video dimensions: ${videoSize.width}x${videoSize.height}")
                    return ""
                }

                // Get bitmap directly from TextureView
val bitmap = textureView.bitmap ?: run {
    Log.e(TAG, "Failed to get bitmap from TextureView")
    return ""
}

// Debugging: Log the dimensions of the bitmap
bitmap.let {
    Log.d(TAG, "Bitmap dimensions: width=${it.width}, height=${it.height}")
    
    // Check if bitmap is empty (all black)
    var hasNonBlackPixel = false
    for (x in 0 until it.width) {
        for (y in 0 until it.height) {
            if (it.getPixel(x, y) != Color.BLACK) {
                hasNonBlackPixel = true
                break
            }
        }
        if (hasNonBlackPixel) break
    }
    
    if (!hasNonBlackPixel) {
        Log.w(TAG, "Bitmap appears to be all black")
    }
}
                // Compress and encode the bitmap
                val byteArrayOutputStream = ByteArrayOutputStream()
                if (bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)) {
                    val byteArray = byteArrayOutputStream.toByteArray()
                    val base64EncodedString = Base64.encodeToString(byteArray, Base64.DEFAULT)
                    Log.d(TAG, "Capture successful, base64 length: ${base64EncodedString.length}")
                    base64EncodedString
                } else {
                    Log.e(TAG, "Failed to compress bitmap")
                    ""
                }
            } ?: run {
                Log.e(TAG, "Cannot capture: player is null")
                ""
                }
            } catch (e: Exception) {
            Log.e(TAG, "Error during capture: ${e.message}", e)
            ""
        }
    }
    
    /**
     * Start recording the video to the specified output path
     * @param outputPath Path where to save the recording
     * @return true if recording started successfully
     */
    fun startRecording(outputPath: String): Boolean {
        Log.d(TAG, "startRecording called with outputPath: $outputPath")
        
        if (isRecording) {
            Log.w(TAG, "Recording is already in progress")
            return false
        }
        
        try {
            player?.let { exoPlayer ->
                // Get the current media item's URI
                val currentUri = exoPlayer.currentMediaItem?.localConfiguration?.uri?.toString()
                if (currentUri == null) {
                    Log.e(TAG, "Current media URI is null")
                    return false
                }
                
                Log.d(TAG, "Current media URI: $currentUri")
                
                // Store the output path
                this.outputPath = if (outputPath.isNullOrEmpty()) {
                    // Use app-specific storage for Android 10+ (API level 29+)
                    val appContext = context.applicationContext
                    val moviesDir = File(appContext.getExternalFilesDir(Environment.DIRECTORY_MOVIES), "recordings")
                    if (!moviesDir.exists()) {
                        moviesDir.mkdirs()
                    }
                    File(moviesDir, "recording_${System.currentTimeMillis()}.mp4").absolutePath
                } else {
                    outputPath
                }
                
                // Create parent directories if they don't exist
                val outputFile = File(this.outputPath)
                outputFile.parentFile?.mkdirs()
                
                // Log the final output path
                Log.d(TAG, "Recording will be saved to: ${this.outputPath}")
                
                // Start a background thread to download the file
                Thread {
                    try {
                        // Create a URL from the URI
                        val url = java.net.URL(currentUri)
                        
                        // Open connection
                        val connection = url.openConnection() as java.net.HttpURLConnection
                        connection.requestMethod = "GET"
                        connection.connectTimeout = 15000
                        connection.readTimeout = 15000
                        connection.doInput = true
                        connection.connect()
                        
                        // Check if the connection was successful
                        if (connection.responseCode != java.net.HttpURLConnection.HTTP_OK) {
                            Log.e(TAG, "HTTP error code: ${connection.responseCode}")
                            return@Thread
                        }
                        
                        // Get the input stream
                        val inputStream = connection.inputStream
                        
                        // Create the output file
                        val outputFile = File(this.outputPath!!)
                        
                        // Create the output stream
                        val outputStream = outputFile.outputStream()
                        
                        // Create a buffer
                        val buffer = ByteArray(1024)
                        var bytesRead: Int
                        var totalBytesRead: Long = 0
                        val fileSize = connection.contentLength.toLong()
                        
                        // Read from the input stream and write to the output stream
                        while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                            outputStream.write(buffer, 0, bytesRead)
                            totalBytesRead += bytesRead
                            
                            // Log progress
                            if (fileSize > 0) {
                                val progress = (totalBytesRead * 100 / fileSize).toInt()
                                Log.d(TAG, "Download progress: $progress%")
                            }
                        }
                        
                        // Close the streams
                        outputStream.flush()
                        outputStream.close()
                        inputStream.close()
                        
                        Log.d(TAG, "File downloaded successfully to ${this.outputPath}")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error downloading file: ${e.message}", e)
                    }
                }.start()
                
                isRecording = true
                Log.d(TAG, "Recording started successfully")
                return true
            } ?: run {
                Log.e(TAG, "Cannot start recording: player is null")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Stop recording and save the video
     * @return Path to the saved recording
     */
    fun stopRecording(): String {
        Log.d(TAG, "stopRecording called")
        
        if (!isRecording) {
            Log.w(TAG, "No recording in progress")
            return ""
        }
        
        // Simply mark recording as stopped
        isRecording = false
        
        // Wait a moment to ensure any background operations complete
        try {
            Thread.sleep(500)
        } catch (e: InterruptedException) {
            Log.e(TAG, "Sleep interrupted: ${e.message}")
        }
        
        // Return the path where the recording was saved
        val savedPath = outputPath ?: ""
        Log.d(TAG, "Recording stopped successfully, saved to: $savedPath")
        
        return savedPath
    }
    
    private fun cleanupRecording() {
        isRecording = false
        outputPath = null
    }
}
