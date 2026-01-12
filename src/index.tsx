import { forwardRef, useImperativeHandle, useRef, useCallback } from 'react';
import {
  requireNativeComponent,
  UIManager,
  NativeModules,
  Platform,
  findNodeHandle,
  type ViewStyle,
} from 'react-native';

// Check if the native module is available
const LINKING_ERROR =
  `The package 'react-native-unified-player' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

// Verify the native module exists
if (
  !UIManager.getViewManagerConfig('UnifiedPlayerView') &&
  !NativeModules.UnifiedPlayer
) {
  throw new Error(LINKING_ERROR);
}

/**
 * Error type for player-related errors
 */
export interface PlayerError {
  code: string;
  message: string;
  nativeError?: unknown;
}

/**
 * Methods available on the player ref
 */
export interface UnifiedPlayerRef {
  /** Start playback */
  play: () => Promise<boolean>;
  /** Pause playback */
  pause: () => Promise<boolean>;
  /** Seek to a specific time in seconds */
  seekTo: (time: number) => Promise<boolean>;
  /** Get current playback time in seconds */
  getCurrentTime: () => Promise<number>;
  /** Get video duration in seconds */
  getDuration: () => Promise<number>;
  /** Capture the current video frame as a base64 encoded image */
  capture: () => Promise<string>;
  /**
   * Start recording/downloading the video.
   * Note: On Android, this downloads the source file rather than recording rendered video.
   */
  startRecording: (outputPath?: string) => Promise<boolean>;
  /** Stop recording and get the path of the saved file */
  stopRecording: () => Promise<string>;
  /** Toggle fullscreen mode */
  toggleFullscreen: (isFullscreen: boolean) => Promise<boolean>;
  /** Set playback speed (e.g., 1.0, 2.0, 4.0, 8.0) */
  setSpeed: (speed: number) => Promise<boolean>;
}

/**
 * Props for the UnifiedPlayerView component
 */
export type UnifiedPlayerProps = {
  /** Video source URL */
  videoUrl: string;
  /** Thumbnail image URL to display until video starts playing */
  thumbnailUrl?: string;
  /** Apply custom styling */
  style: ViewStyle;
  /** Autoplay video when loaded */
  autoplay?: boolean;
  /** Should video loop when finished */
  loop?: boolean;
  /** Is the player currently paused */
  isPaused?: boolean;
  /** Callback when video begins loading */
  onLoadStart?: () => void;
  /** Callback when video is ready to play */
  onReadyToPlay?: () => void;
  /** Callback when an error occurs */
  onError?: (error: PlayerError) => void;
  /** Callback when video playback finishes */
  onPlaybackComplete?: () => void;
  /** Callback for playback progress */
  onProgress?: (data: { currentTime: number; duration: number }) => void;
  /** Callback when playback is stalled (buffering) */
  onPlaybackStalled?: () => void;
  /** Callback when playback resumes after stalling */
  onPlaybackResumed?: () => void;
  /** Callback when playback is paused */
  onPaused?: () => void;
  /** Callback when playback is playing */
  onPlaying?: () => void;
  /** Fullscreen mode - automatically rotates to landscape when true */
  isFullscreen?: boolean;
  /** Callback when fullscreen state changes */
  onFullscreenChanged?: (isFullscreen: boolean) => void;
};

// Native component registration
const NativeUnifiedPlayerView =
  requireNativeComponent<UnifiedPlayerProps>('UnifiedPlayerView');

// Native module for player control methods
const NativeModule = NativeModules.UnifiedPlayer;

// Export event types for reference
export const UnifiedPlayerEventTypes = {
  LOAD_START: 'onLoadStart',
  READY: 'onReadyToPlay',
  ERROR: 'onError',
  PROGRESS: 'onProgress',
  COMPLETE: 'onPlaybackComplete',
  STALLED: 'onPlaybackStalled',
  RESUMED: 'onPlaybackResumed',
  PLAYING: 'onPlaying',
  PAUSED: 'onPaused',
} as const;

/**
 * UnifiedPlayerView component for video playback.
 *
 * @example
 * ```tsx
 * const playerRef = useRef<UnifiedPlayerRef>(null);
 *
 * // Control playback
 * await playerRef.current?.play();
 * await playerRef.current?.pause();
 * await playerRef.current?.seekTo(30);
 *
 * // Get player state
 * const currentTime = await playerRef.current?.getCurrentTime();
 * const duration = await playerRef.current?.getDuration();
 *
 * // Capture frame
 * const base64Image = await playerRef.current?.capture();
 *
 * return (
 *   <UnifiedPlayerView
 *     ref={playerRef}
 *     videoUrl="https://example.com/video.mp4"
 *     style={{ width: '100%', height: 300 }}
 *     autoplay
 *   />
 * );
 * ```
 */
export const UnifiedPlayerView = forwardRef<
  UnifiedPlayerRef,
  UnifiedPlayerProps
>((props, ref) => {
  const nativeRef = useRef<any>(null);

  const getViewTag = useCallback((): number | null => {
    return findNodeHandle(nativeRef.current);
  }, []);

  const callNativeMethod = useCallback(
    async <T,>(
      methodName: string,
      method: (viewTag: number, ...args: any[]) => Promise<T>,
      ...args: any[]
    ): Promise<T> => {
      const viewTag = getViewTag();
      if (viewTag === null) {
        throw new Error('Player view not found');
      }

      if (__DEV__) {
        console.log(`UnifiedPlayer.${methodName} called`);
      }

      try {
        const result = await method(viewTag, ...args);
        if (__DEV__) {
          console.log(`${methodName} completed successfully`);
        }
        return result;
      } catch (error) {
        if (__DEV__) {
          console.error(
            `Error in ${methodName}:`,
            error instanceof Error ? error.message : String(error)
          );
        }
        throw error;
      }
    },
    [getViewTag]
  );

  useImperativeHandle(
    ref,
    () => ({
      play: () => callNativeMethod('play', NativeModule.play),
      pause: () => callNativeMethod('pause', NativeModule.pause),
      seekTo: (time: number) =>
        callNativeMethod('seekTo', NativeModule.seekTo, time),
      getCurrentTime: () =>
        callNativeMethod('getCurrentTime', NativeModule.getCurrentTime),
      getDuration: () =>
        callNativeMethod('getDuration', NativeModule.getDuration),
      capture: () => callNativeMethod('capture', NativeModule.capture),
      startRecording: (outputPath?: string) =>
        callNativeMethod(
          'startRecording',
          NativeModule.startRecording,
          outputPath
        ),
      stopRecording: () =>
        callNativeMethod('stopRecording', NativeModule.stopRecording),
      toggleFullscreen: (isFullscreen: boolean) =>
        callNativeMethod(
          'toggleFullscreen',
          NativeModule.toggleFullscreen,
          isFullscreen
        ),
      setSpeed: (speed: number) =>
        callNativeMethod('setSpeed', NativeModule.setSpeed, speed),
    }),
    [callNativeMethod]
  );

  return <NativeUnifiedPlayerView {...props} ref={nativeRef} />;
});
