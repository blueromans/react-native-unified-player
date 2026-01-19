package com.margelo.nitro.unifiedplayer

import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.drm.DrmSessionManager
import androidx.media3.exoplayer.source.MediaSource
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import com.unifiedplayer.core.LibraryError
import com.unifiedplayer.core.player.DRMManagerSpec
import com.unifiedplayer.core.player.buildMediaSource
import com.unifiedplayer.core.player.createMediaItemFromVideoConfig
import com.unifiedplayer.core.plugins.PluginsRegistry
import com.unifiedplayer.core.utils.SourceLoader
import com.unifiedplayer.core.utils.VideoInformationUtils

class HybridVideoPlayerSource(): HybridVideoPlayerSourceSpec() {
  override lateinit var uri: String
  override lateinit var config: NativeVideoConfig

  private lateinit var mediaItem: MediaItem
  lateinit var mediaSource: MediaSource

  var drmManager: DRMManagerSpec? = null

  @UnstableApi
  var drmSessionManager: DrmSessionManager? = null

  internal val sourceLoader = SourceLoader()

  constructor(config: NativeVideoConfig) : this() {
    this.uri = config.uri
    this.config = config

    val overriddenSource = PluginsRegistry.shared.overrideSource(this)

    config.drm?.let {
      drmManager = PluginsRegistry.shared.getDRMManager(this)
      drmSessionManager = drmManager?.buildDrmSessionManager(it)
    }

    this.mediaItem = createMediaItemFromVideoConfig(
      overriddenSource
    )

    NitroModules.applicationContext?.let {
      this.mediaSource = buildMediaSource(
        context = it,
        source = overriddenSource,
        mediaItem
      )
    } ?: run {
      throw LibraryError.ApplicationContextNotFound
    }
  }

  override fun getAssetInformationAsync(): Promise<VideoInformation> {
    return Promise.async {
      return@async sourceLoader.load {
        VideoInformationUtils.fromUri(uri, config.headers ?: emptyMap())
      }
    }
  }

  override val memorySize: Long
    get() = 0
}
