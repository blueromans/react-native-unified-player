package com.unifiedplayer.core.extensions

import com.margelo.nitro.unifiedplayer.SubtitleType

fun SubtitleType.toStringExtension(): String {
  return when {
    this == SubtitleType.AUTO -> "auto"
    this == SubtitleType.VTT -> "vtt"
    this == SubtitleType.SRT -> "srt"
    this == SubtitleType.SSA -> "ssa"
    this == SubtitleType.ASS -> "ass"
    else -> throw IllegalArgumentException("Unknown SubtitleType: $this")
  }
}
