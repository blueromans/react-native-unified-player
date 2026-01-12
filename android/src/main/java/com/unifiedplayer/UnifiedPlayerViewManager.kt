package com.unifiedplayer

import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.common.MapBuilder
import android.util.Log

class UnifiedPlayerViewManager : SimpleViewManager<UnifiedPlayerView>() {
  private val TAG = "UnifiedPlayerViewManager"

  override fun getName() = "UnifiedPlayerView"

  override fun createViewInstance(reactContext: ThemedReactContext): UnifiedPlayerView {
    Log.d(TAG, "Creating UnifiedPlayerView instance")
    return UnifiedPlayerView(reactContext)
  }

  @ReactProp(name = "videoUrl")
  fun setVideoUrl(view: UnifiedPlayerView, url: String?) {
    view.setVideoUrl(url)
  }

  @ReactProp(name = "thumbnailUrl")
  fun setThumbnailUrl(view: UnifiedPlayerView, url: String?) {
    view.setThumbnailUrl(url)
  }

  @ReactProp(name = "autoplay")
  fun setAutoplay(view: UnifiedPlayerView, autoplay: Boolean) {
    view.setAutoplay(autoplay)
  }

  @ReactProp(name = "loop")
  fun setLoop(view: UnifiedPlayerView, loop: Boolean) {
    view.setLoop(loop)
  }

  @ReactProp(name = "isPaused")
  fun setIsPaused(view: UnifiedPlayerView, isPaused: Boolean) {
    view.setIsPaused(isPaused)
  }

  @ReactProp(name = "isFullscreen")
  fun setIsFullscreen(view: UnifiedPlayerView, isFullscreen: Boolean) {
    view.setIsFullscreen(isFullscreen)
  }


  
  // Register direct events
  override fun getExportedCustomDirectEventTypeConstants(): Map<String, Any> {
    Log.d(TAG, "Registering direct events")
    
    // Create a map of event names to their registration names
    return MapBuilder.builder<String, Any>()
      .put("topReadyToPlay", MapBuilder.of("registrationName", "onReadyToPlay"))
      .put("topError", MapBuilder.of("registrationName", "onError"))
      .put("topProgress", MapBuilder.of("registrationName", "onProgress"))
      .put("topPlaybackComplete", MapBuilder.of("registrationName", "onPlaybackComplete"))
      .put("topPlaybackResumed", MapBuilder.of("registrationName", "onPlaybackResumed"))
      .put("topPlaybackStalled", MapBuilder.of("registrationName", "onPlaybackStalled"))
      .put("topPlaybackPaused", MapBuilder.of("registrationName", "onPaused"))
      .put("topPlaying", MapBuilder.of("registrationName", "onPlaying"))
      .put("topLoadStart", MapBuilder.of("registrationName", "onLoadStart"))
      .put("topFullscreenChanged", MapBuilder.of("registrationName", "onFullscreenChanged"))
      .build()
  }
}
