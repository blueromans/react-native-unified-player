# react-native-unified-player

Unified Player

A React Native component for playing videos via URL, built with Fabric.

## Features

- 🎥 Play videos from a URL source
- 📱 Native performance with Fabric architecture
- 📊 Event handling for player states (Ready, Error, Progress, Complete, Stalled, Resumed)
- 🎛️ Control playback with methods (Play, Pause, Seek, Get Current Time, Get Duration)
- 🔄 Optional autoplay and loop

## Installation

```bash
yarn add react-native-unified-player
```

or

```bash
npm install react-native-unified-player
```

## Usage

### Basic Usage

```typescript
import { UnifiedPlayerView, UnifiedPlayer, UnifiedPlayerEventTypes, UnifiedPlayerEvents } from 'react-native-unified-player';
import React, { useRef, useEffect } from 'react';
import { View } from 'react-native';

const MyPlayerComponent = () => {
  const playerRef = useRef(null);

  // Example of using event listeners (optional)
  useEffect(() => {
    const readyListener = UnifiedPlayerEvents.addListener(UnifiedPlayerEventTypes.READY, () => {
      console.log('Player is ready to play');
      // You can call UnifiedPlayer methods here, e.g., UnifiedPlayer.play(playerRef.current.getNativeTag());
    });

    const errorListener = UnifiedPlayerEvents.addListener(UnifiedPlayerEventTypes.ERROR, (error) => {
      console.error('Player error:', error);
    });

    // Add other listeners as needed (PROGRESS, COMPLETE, STALLED, RESUMED)

    return () => {
      // Clean up listeners on unmount
      readyListener.remove();
      errorListener.remove();
      // Remove other listeners
    };
  }, []);

  return (
    <View style={{ flex: 1 }}>
      <UnifiedPlayerView
        ref={playerRef}
        style={{ width: '100%', height: 300 }} // Example style
        videoUrl="YOUR_VIDEO_URL_HERE" // Replace with your video URL
        autoplay={false} // Optional: set to true to autoplay
        loop={false} // Optional: set to true to loop
        // You can also use direct view props instead of or in addition to event listeners:
        // onReadyToPlay={() => console.log('View prop: Ready to play')}
        // onError={(e) => console.log('View prop: Error', e)}
        // onPlaybackComplete={() => console.log('View prop: Playback complete')}
        // onProgress={(data) => console.log('View prop: Progress', data)}
      />
    </View>
  );
};

export default MyPlayerComponent;
```

## Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `videoUrl` | `string` \| `string[]` | Yes | Video source URL or an array of URLs for a playlist. |
| `style` | `ViewStyle` | Yes | Apply custom styling |
| `autoplay` | `boolean` | No | Autoplay video when loaded |
| `loop` | `boolean` | No | Should the video/playlist loop when finished. **Note:** Playlist advancement and looping are handled in the JavaScript layer via the `onPlaybackComplete` callback. The native player only loops single videos based on this prop. |
| `onLoadStart` | `(event: { nativeEvent?: { index?: number } }) => void` | No | Callback when video begins loading. The `event.nativeEvent` may contain an `index` property on Android when playing a playlist. |
| `onReadyToPlay` | `() => void` | No | Callback when video is ready to play |
| `onError` | `(error: any) => void` | No | Callback when an error occurs |
| `onPlaybackComplete` | `() => void` | No | Callback when video playback finishes. Use this callback to implement playlist advancement logic in your JavaScript code. |
| `onProgress` | `(data: { currentTime: number; duration: number }) => void` | No | Callback for playback progress |

## Events

Events can be listened to using `UnifiedPlayerEvents.addListener(eventType, listener)`. The available event types are defined in `UnifiedPlayerEventTypes`.

- `UnifiedPlayerEventTypes.READY` ('onReadyToPlay'): Fired when the player is ready to play.
- `UnifiedPlayerEventTypes.ERROR` ('onError'): Fired when an error occurs.
- `UnifiedPlayerEventTypes.PROGRESS` ('onProgress'): Fired during playback with current time and duration (`{ currentTime: number; duration: number }`).
- `UnifiedPlayerEventTypes.COMPLETE` ('onPlaybackComplete'): Fired when video playback finishes.
- `UnifiedPlayerEventTypes.STALLED` ('onPlaybackStalled'): Fired when playback stalls.
- `UnifiedPlayerEventTypes.RESUMED` ('onPlaybackResumed'): Fired when playback resumes after stalling.

## Methods

Control playback using the `UnifiedPlayer` object and the native tag of the `UnifiedPlayerView` instance (obtained via `ref.current.getNativeTag()`).

- `UnifiedPlayer.play(viewTag: number)`: Starts video playback.
- `UnifiedPlayer.pause(viewTag: number)`: Pauses video playback.
- `UnifiedPlayer.seekTo(viewTag: number, time: number)`: Seeks to a specific time in seconds.
- `UnifiedPlayer.getCurrentTime(viewTag: number): Promise<number>`: Gets the current playback time in seconds.
- `UnifiedPlayer.getDuration(viewTag: number): Promise<number>`: Gets the duration of the video in seconds.

## Development

### Prerequisites

- Node.js >= 16
- Yarn >= 1.22
- React Native >= 0.79.0
- iOS: Xcode >= 14.0
- Android: Android Studio >= 2022.3

### Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   yarn install
   ```
3. Build the project:
   ```bash
   yarn prepare
   ```

### Running the Example App

1. Navigate to the example directory:
   ```bash
   cd example
   ```
2. Install dependencies:
   ```bash
   yarn install
   ```
3. Run the app:
   ```bash
   yarn ios  # for iOS
   yarn android  # for Android
   ```

## Publishing

This package is automatically published to npm when changes are pushed to the `main` or `master` branch. See [PUBLISHING.md](.github/PUBLISHING.md) for setup instructions and details about npm's new authentication system (granular access tokens).

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Yaşar Özyurt ([@blueromans](https://github.com/blueromans))

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
