package com.unifiedplayer.core.fragments

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.annotation.OptIn
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.media3.common.util.UnstableApi
import com.unifiedplayer.core.utils.PictureInPictureUtils.createPictureInPictureParams
import com.unifiedplayer.core.utils.SmallVideoPlayerOptimizer
import com.unifiedplayer.view.VideoView
import java.util.UUID

@OptIn(UnstableApi::class)
class FullscreenVideoFragment(private val videoView: VideoView) : Fragment() {
  val id: String = UUID.randomUUID().toString()

  private var container: FrameLayout? = null
  private var originalPlayerParent: ViewGroup? = null
  private var originalPlayerLayoutParams: ViewGroup.LayoutParams? = null
  private var rootContentViews: List<View> = listOf()
  private var originalOrientation: Int? = null

  // Back press callback to handle back navigation
  private val backPressCallback = object : OnBackPressedCallback(true) {
    override fun handleOnBackPressed() {
      videoView.exitFullscreen()
    }
  }

  override fun onCreateView(
    inflater: LayoutInflater,
    container: ViewGroup?,
    savedInstanceState: Bundle?
  ): View? {
    // Create a fullscreen container
    this.container = FrameLayout(requireContext()).apply {
      layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
      )
      setBackgroundColor(android.graphics.Color.BLACK)
      keepScreenOn = true
    }
    return this.container
  }

  override fun onSaveInstanceState(outState: Bundle) {
    super.onSaveInstanceState(outState)
    originalOrientation?.let { outState.putInt("originalOrientation", it) }
  }

  override fun onResume() {
    super.onResume()

    // System UI is re-enabled when user have exited app and go back
    // We need to hide it again
    hideSystemUI()
  }

  override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
    super.onViewCreated(view, savedInstanceState)

    // Register back press callback
    requireActivity().onBackPressedDispatcher.addCallback(viewLifecycleOwner, backPressCallback)

    enterFullscreenMode()
    setupPlayerView()
    hideSystemUI()

    // Update PiP params if supported
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      try {
        val params = createPictureInPictureParams(videoView)
        requireActivity().setPictureInPictureParams(params)
      } catch (_: Exception) {}
    }



    // Creating a fullscreen fragment usually means we want to be in landscape
    if (savedInstanceState != null && savedInstanceState.containsKey("originalOrientation")) {
      originalOrientation = savedInstanceState.getInt("originalOrientation")
    } else {
      originalOrientation = requireActivity().requestedOrientation
    }
    requireActivity().requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
  }

  override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
    super.onPictureInPictureModeChanged(isInPictureInPictureMode)

    if (isInPictureInPictureMode) {
      videoView.playerView.useController = false
      videoView.playerView.controllerAutoShow = false
    } else {
      // In fullscreen, we always want controls enabled
      videoView.playerView.useController = true
      videoView.playerView.controllerAutoShow = true
    }
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)

    val isInPictureInPictureMode = requireActivity().isInPictureInPictureMode

    if (isInPictureInPictureMode) {
      videoView.playerView.useController = false
      videoView.playerView.controllerAutoShow = false
    } else {
      // In fullscreen, we always want controls enabled
      videoView.playerView.useController = true
      videoView.playerView.controllerAutoShow = true
    }
  }

  private fun enterFullscreenMode() {
    // Store original parent and layout params
    originalPlayerParent = videoView.playerView.parent as? ViewGroup
    originalPlayerLayoutParams = videoView.playerView.layoutParams

    // Remove player from original parent
    originalPlayerParent?.removeView(videoView.playerView)

    // Hide all root content views
    val currentActivity = requireActivity()
    val rootContent = currentActivity.window.decorView.findViewById<ViewGroup>(android.R.id.content)
    rootContentViews = (0 until rootContent.childCount)
      .map { rootContent.getChildAt(it) }
      .filter { it.isVisible }

    rootContentViews.forEach { view ->
      view.visibility = View.GONE
    }

    // Add our fullscreen container to root
    rootContent.addView(container,
      ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
      )
    )
  }

  private fun setupPlayerView() {
    // Add PlayerView to our container
    container?.addView(videoView.playerView,
      FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        FrameLayout.LayoutParams.MATCH_PARENT
      )
    )

    videoView.playerView.setBackgroundColor(android.graphics.Color.BLACK)
    videoView.playerView.setShutterBackgroundColor(android.graphics.Color.BLACK)

    // We need show controls in fullscreen
    videoView.playerView.useController = true

    setupFullscreenButton()
    videoView.playerView.setShowSubtitleButton(true)
    
    // Apply optimizations based on video player size in fullscreen mode
    SmallVideoPlayerOptimizer.applyOptimizations(videoView.playerView, requireContext(), isFullscreen = true)

    // Add close button after player view so it's on top
    setupCloseButton()

    // Add playback speed button logic
    setupPlaybackSpeedButton()

    // Show controller initially
    videoView.playerView.showController()
  }

  private fun setupPlaybackSpeedButton() {
    val speedButton = videoView.playerView.findViewById<TextView>(com.unifiedplayer.R.id.exo_playback_speed)
    
    speedButton?.setOnClickListener {
      val player = videoView.playerView.player ?: return@setOnClickListener
      val currentSpeed = player.playbackParameters.speed
      
      val nextSpeed = when (currentSpeed) {
        1.0f -> 2.0f
        2.0f -> 4.0f
        4.0f -> 1.0f
        else -> 1.0f
      }
      
      player.setPlaybackSpeed(nextSpeed)
      speedButton.text = "${nextSpeed}x"
    }
  }

  private fun setupCloseButton() {
    val context = requireContext()
    val closeButton = ImageButton(context).apply {
      setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
      setBackgroundColor(android.graphics.Color.TRANSPARENT)
      setColorFilter(android.graphics.Color.WHITE)
      setPadding(16, 16, 16, 16)
      
      layoutParams = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
      ).apply {
        gravity = Gravity.TOP or Gravity.START
        topMargin = 64
        leftMargin = 64
      }
      
      setOnClickListener {
        exitFullscreen()
      }
    }
    
    container?.addView(closeButton)
  }

  @SuppressLint("PrivateResource")
  private fun setupFullscreenButton() {
    videoView.playerView.setFullscreenButtonClickListener { _ ->
      videoView.exitFullscreen()
    }

    // Change icon to exit fullscreen
    val button = videoView.playerView.findViewById<ImageButton>(androidx.media3.ui.R.id.exo_fullscreen)
    button?.setImageResource(androidx.media3.ui.R.drawable.exo_icon_fullscreen_exit)
  }

  @Suppress("DEPRECATION")
  private fun hideSystemUI() {
    val currentActivity = requireActivity()
    container?.let { container ->
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        container.fitsSystemWindows = false
        container.windowInsetsController?.let { controller ->
          controller.hide(WindowInsets.Type.systemBars())
          controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
      } else {
        currentActivity.window.decorView.systemUiVisibility = (
          View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
          or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
          or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
          or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
          or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
          or View.SYSTEM_UI_FLAG_FULLSCREEN
        )
      }
    }
  }

  @Suppress("DEPRECATION")
  private fun restoreSystemUI() {
    val currentActivity = requireActivity()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      container?.windowInsetsController?.show(WindowInsets.Type.systemBars())
    } else {
      currentActivity.window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
    }
  }

  fun exitFullscreen() {
    // Remove back press callback since we're exiting
    backPressCallback.remove()

    restoreSystemUI()

    // Restore original orientation
    originalOrientation?.let { orientation ->
      requireActivity().requestedOrientation = orientation
    }
    originalOrientation = null

    // Keep controls disabled if in PiP mode - media session creates its own controls for PiP
    val isInPictureInPictureMode = requireActivity().isInPictureInPictureMode
    if (isInPictureInPictureMode) {
      videoView.playerView.useController = false
    } else if (videoView.useController == false) {
      videoView.playerView.useController = false
    }

    // Ensure PlayerView keeps black background when returning to normal mode
    videoView.playerView.setBackgroundColor(android.graphics.Color.BLACK)
    videoView.playerView.setShutterBackgroundColor(android.graphics.Color.BLACK)

  // Remove PlayerView from our container
  container?.removeView(videoView.playerView)

    // Remove our container from root
    val currentActivity = requireActivity()
    val rootContent = currentActivity.window.decorView.findViewById<ViewGroup>(android.R.id.content)
    rootContent.removeView(container)

    // Restore root content views
    rootContentViews.forEach { it.visibility = View.VISIBLE }
    rootContentViews = listOf()

    // Safely restore PlayerView to original parent
    // First, ensure PlayerView is removed from any current parent
    val currentParent = videoView.playerView.parent as? ViewGroup
    currentParent?.removeView(videoView.playerView)

    // Now add it back to the original parent if it's not already the parent
    if (videoView.playerView.parent != originalPlayerParent) {
      originalPlayerParent?.addView(videoView.playerView, originalPlayerLayoutParams)
    }

    // Remove this fragment
    parentFragmentManager.beginTransaction()
      .remove(this)
      .commitAllowingStateLoss()

    // Notify VideoView that we've exited fullscreen
    videoView.isInFullscreen = false
  }



  override fun onDestroy() {
    super.onDestroy()

    // Ensure we clean up properly if fragment is destroyed
    if (videoView.isInFullscreen) {
      exitFullscreen()
    }
  }
}
