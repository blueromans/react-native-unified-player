<p align="center">
  <img src="https://img.shields.io/npm/v/react-native-unified-player?style=flat-square&color=blue" alt="npm version" />
  <img src="https://img.shields.io/npm/dm/react-native-unified-player?style=flat-square&color=green" alt="npm downloads" />
  <img src="https://img.shields.io/badge/platforms-iOS%20%7C%20Android-lightgrey?style=flat-square" alt="platforms" />
  <img src="https://img.shields.io/github/license/blueromans/react-native-unified-player?style=flat-square" alt="license" />
</p>

<h1 align="center">React Native Unified Player</h1>

<p align="center">
  <b>A high-performance video player for React Native</b><br/>
  Built with <a href="https://github.com/mrousavy/nitro">Nitro Modules</a> for blazing-fast native performance
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#api-reference">API</a> •
  <a href="#examples">Examples</a>
</p>

---

## Features

| Feature | iOS | Android |
|---------|:---:|:-------:|
| HLS / DASH Streaming | ✅ | ✅ |
| Local & Remote Files | ✅ | ✅ |
| Fullscreen Mode | ✅ | ✅ |
| Picture-in-Picture | ✅ | ✅ |
| Background Playback | ✅ | ✅ |
| Notification Controls | ✅ | ✅ |
| Subtitles / Text Tracks | ✅ | ✅ |
| Playback Speed Control | ✅ | ✅ |
| Frame Capture | ✅ | ✅ |
| DRM Support | 🔜 | 🔜 |

**Why Unified Player?**

- **Nitro Modules** - Direct native calls without bridge overhead
- **AVPlayer & ExoPlayer** - Industry-standard players under the hood
- **Declarative API** - Modern React hooks-based architecture
- **TypeScript First** - Full type safety out of the box

---

## Installation

```bash
# Using yarn
yarn add react-native-unified-player react-native-nitro-modules

# Using npm
npm install react-native-unified-player react-native-nitro-modules
```

### iOS Setup

```bash
cd ios && pod install
```

### Android Setup

No additional configuration required.

---

## Quick Start

```tsx
import React from 'react';
import { View, StyleSheet } from 'react-native';
import { UnifiedPlayerView, useVideoPlayer } from 'react-native-unified-player';

export default function App() {
  const player = useVideoPlayer({
    uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  });

  return (
    <View style={styles.container}>
      <UnifiedPlayerView
        player={player}
        style={styles.video}
        controls
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  video: { width: '100%', aspectRatio: 16 / 9 },
});
```

---

## Examples

<details>
<summary><b>🎮 With Playback Controls</b></summary>

```tsx
import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { UnifiedPlayerView, useVideoPlayer } from 'react-native-unified-player';

export default function PlayerWithControls() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState({ current: 0, duration: 0 });

  const player = useVideoPlayer({ uri: 'https://example.com/video.mp4' }, (p) => {
    p.loop = true;

    p.addEventListener('onPlaybackStateChange', ({ isPlaying }) => {
      setIsPlaying(isPlaying);
    });

    p.addEventListener('onProgress', ({ currentTime, duration }) => {
      setProgress({ current: currentTime, duration });
    });
  });

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <View style={styles.container}>
      <UnifiedPlayerView player={player} style={styles.video} />

      <View style={styles.controls}>
        <TouchableOpacity onPress={() => player.seekBy(-10)}>
          <Text style={styles.button}>-10s</Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={() => isPlaying ? player.pause() : player.play()}>
          <Text style={styles.button}>{isPlaying ? '⏸️' : '▶️'}</Text>
        </TouchableOpacity>

        <TouchableOpacity onPress={() => player.seekBy(10)}>
          <Text style={styles.button}>+10s</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.time}>
        {formatTime(progress.current)} / {formatTime(progress.duration)}
      </Text>
    </View>
  );
}
```

</details>

<details>
<summary><b>📺 Fullscreen Mode</b></summary>

```tsx
import React, { useState } from 'react';
import { View, Button } from 'react-native';
import { UnifiedPlayerView, useVideoPlayer } from 'react-native-unified-player';

export default function FullscreenExample() {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const player = useVideoPlayer({ uri: 'https://example.com/video.mp4' });

  return (
    <View style={{ flex: 1 }}>
      <UnifiedPlayerView
        player={player}
        style={{ width: '100%', aspectRatio: 16 / 9 }}
        fullscreen={isFullscreen}
        onFullscreenChange={setIsFullscreen}
      />

      <Button
        title={isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen'}
        onPress={() => setIsFullscreen(!isFullscreen)}
      />
    </View>
  );
}
```

</details>

<details>
<summary><b>📸 Capture Video Frame</b></summary>

```tsx
import React, { useState } from 'react';
import { View, Button, Image } from 'react-native';
import { UnifiedPlayerView, useVideoPlayer } from 'react-native-unified-player';

export default function FrameCaptureExample() {
  const [thumbnail, setThumbnail] = useState<string | null>(null);
  const player = useVideoPlayer({ uri: 'https://example.com/video.mp4' });

  const captureFrame = async () => {
    try {
      const base64 = await player.captureFrame();
      setThumbnail(`data:image/png;base64,${base64}`);
    } catch (error) {
      console.error('Capture failed:', error);
    }
  };

  return (
    <View style={{ flex: 1 }}>
      <UnifiedPlayerView
        player={player}
        style={{ width: '100%', aspectRatio: 16 / 9 }}
      />

      <Button title="Capture Frame" onPress={captureFrame} />

      {thumbnail && (
        <Image
          source={{ uri: thumbnail }}
          style={{ width: 200, height: 112, marginTop: 20 }}
        />
      )}
    </View>
  );
}
```

</details>

<details>
<summary><b>🎚️ Playback Speed Control</b></summary>

```tsx
import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { UnifiedPlayerView, useVideoPlayer } from 'react-native-unified-player';

const SPEEDS = [0.5, 1.0, 1.25, 1.5, 2.0];

export default function SpeedControlExample() {
  const [speed, setSpeed] = useState(1.0);
  const player = useVideoPlayer({ uri: 'https://example.com/video.mp4' });

  const changeSpeed = (newSpeed: number) => {
    player.rate = newSpeed;
    setSpeed(newSpeed);
  };

  return (
    <View style={{ flex: 1 }}>
      <UnifiedPlayerView
        player={player}
        style={{ width: '100%', aspectRatio: 16 / 9 }}
      />

      <View style={styles.speedButtons}>
        {SPEEDS.map((s) => (
          <TouchableOpacity
            key={s}
            onPress={() => changeSpeed(s)}
            style={[styles.speedBtn, speed === s && styles.activeSpeed]}
          >
            <Text>{s}x</Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}
```

</details>

<details>
<summary><b>📝 Subtitles / Text Tracks</b></summary>

```tsx
const player = useVideoPlayer({
  uri: 'https://example.com/video.mp4',
  externalSubtitles: [
    {
      label: 'English',
      language: 'en',
      uri: 'https://example.com/subs-en.vtt',
      type: 'vtt',
    },
    {
      label: 'Spanish',
      language: 'es',
      uri: 'https://example.com/subs-es.vtt',
      type: 'vtt',
    },
  ],
});

// Get available tracks
const tracks = player.getAvailableTextTracks();

// Select a track
player.selectTextTrack(tracks[0]);

// Disable subtitles
player.selectTextTrack(null);
```

</details>

---

## API Reference

### `useVideoPlayer(source, setup?)`

Creates a video player instance.

```tsx
const player = useVideoPlayer(
  { uri: 'https://example.com/video.mp4' },
  (player) => {
    // Optional setup callback
    player.loop = true;
    player.volume = 0.8;
  }
);
```

#### Source Options

| Property | Type | Description |
|----------|------|-------------|
| `uri` | `string` | Video URL (required) |
| `headers` | `Record<string, string>` | HTTP headers for the request |
| `bufferConfig` | `BufferConfig` | Buffer configuration |
| `externalSubtitles` | `ExternalSubtitle[]` | External subtitle tracks |

---

### `<UnifiedPlayerView />`

Video player component.

#### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `player` | `VideoPlayer` | *required* | Player instance from `useVideoPlayer` |
| `style` | `ViewStyle` | - | View styling |
| `controls` | `boolean` | `false` | Show native controls |
| `fullscreen` | `boolean` | `false` | Fullscreen mode |
| `autoplay` | `boolean` | `true` | Auto-start playback |
| `resizeMode` | `ResizeMode` | `'none'` | `'contain'` \| `'cover'` \| `'stretch'` \| `'none'` |
| `pictureInPicture` | `boolean` | `false` | Enable PiP button |
| `autoEnterPictureInPicture` | `boolean` | `false` | Auto-enter PiP on background |
| `keepScreenAwake` | `boolean` | `true` | Prevent screen sleep |
| `surfaceType` | `SurfaceType` | `'surface'` | Android: `'surface'` \| `'texture'` |

#### Events

| Event | Callback |
|-------|----------|
| `onFullscreenChange` | `(isFullscreen: boolean) => void` |
| `onPictureInPictureChange` | `(isInPiP: boolean) => void` |
| `willEnterFullscreen` | `() => void` |
| `willExitFullscreen` | `() => void` |
| `willEnterPictureInPicture` | `() => void` |
| `willExitPictureInPicture` | `() => void` |

---

### VideoPlayer Instance

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `currentTime` | `number` | Current position (seconds) |
| `duration` | `number` | Total duration (seconds) |
| `volume` | `number` | Volume (0.0 - 1.0) |
| `muted` | `boolean` | Mute state |
| `rate` | `number` | Playback speed (1.0 = normal) |
| `loop` | `boolean` | Loop playback |
| `isPlaying` | `boolean` | Playing state |
| `status` | `VideoPlayerStatus` | `'idle'` \| `'loading'` \| `'readyToPlay'` \| `'error'` |

#### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `play()` | `void` | Start playback |
| `pause()` | `void` | Pause playback |
| `seekTo(seconds)` | `void` | Seek to position |
| `seekBy(seconds)` | `void` | Seek relative |
| `captureFrame()` | `Promise<string>` | Capture frame as base64 PNG |
| `getAvailableTextTracks()` | `TextTrack[]` | Get subtitle tracks |
| `selectTextTrack(track)` | `void` | Select subtitle track |
| `release()` | `void` | Release resources |

#### Events

Subscribe with `player.addEventListener(event, callback)`:

| Event | Payload |
|-------|---------|
| `onLoad` | `{ currentTime, duration, width, height, orientation }` |
| `onProgress` | `{ currentTime, duration, bufferDuration }` |
| `onPlaybackStateChange` | `{ isPlaying, isBuffering }` |
| `onStatusChange` | `VideoPlayerStatus` |
| `onEnd` | - |
| `onError` | `VideoRuntimeError` |
| `onBuffer` | `boolean` |
| `onSeek` | `number` |
| `onPlaybackRateChange` | `number` |
| `onVolumeChange` | `{ volume, muted }` |

---

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| React Native | 0.76.0 |
| iOS | 15.1 |
| Android | SDK 24 (Android 7.0) |
| Nitro Modules | 0.27.2 |

---

## Migration from v0.x

Version 1.0.0 introduces a new architecture. Here's how to migrate:

```diff
- import { UnifiedPlayerView, UnifiedPlayer } from 'react-native-unified-player';
+ import { UnifiedPlayerView, useVideoPlayer } from 'react-native-unified-player';

- const playerRef = useRef(null);
+ const player = useVideoPlayer({ uri: videoUrl });

- <UnifiedPlayerView
-   ref={playerRef}
-   videoUrl={videoUrl}
-   onReadyToPlay={() => console.log('Ready')}
- />
+ <UnifiedPlayerView
+   player={player}
+   controls
+ />

- UnifiedPlayer.play(playerRef.current.getNativeTag());
+ player.play();
```

---

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) before submitting a PR.

## License

MIT © [Yaşar Özyurt](https://github.com/blueromans)

---

<p align="center">
  <sub>Built with ❤️ using <a href="https://github.com/mrousavy/nitro">Nitro Modules</a></sub>
</p>
