import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  Alert,
  NativeModules,
  Platform,
  PermissionsAndroid,
} from 'react-native';
import {
  UnifiedPlayerView,
  UnifiedPlayerEventTypes,
  type UnifiedPlayerRef,
  type PlayerError,
} from 'react-native-unified-player';
import { SimpleExample } from './SimpleExample';
import {
  ControlButton,
  PlayerControls,
  ProgressDisplay,
  CapturedFrame,
  RecordingControls,
} from './components';

const singleVideoUrl =
  'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_1MB.mp4';
const singleThumbnailUrl =
  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg';

function App(): React.JSX.Element {
  const [showSimpleExample, setShowSimpleExample] = useState(true);
  const playerRef = useRef<UnifiedPlayerRef>(null);
  const [currentVideoSource, setCurrentVideoSource] =
    useState<string>(singleVideoUrl);
  const [thumbnailUrl] = useState<string>(singleThumbnailUrl);
  const [autoplay, setAutoplay] = useState(true);
  const [loop, setLoop] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);

  const [isPlayerReady, setIsPlayerReady] = useState(false);
  const lastProgressTimeRef = useRef(0);
  const lastDurationRef = useRef(0);
  const [progressEventsReceived, setProgressEventsReceived] = useState(false);
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [recordedVideoPath, setRecordedVideoPath] = useState<string | null>(
    null
  );

  const reinitializePlayer = useCallback(async () => {
    console.log('Attempting to reinitialize player');
    try {
      await playerRef.current?.pause();
      await new Promise<void>((resolve) => setTimeout(resolve, 500));
      await playerRef.current?.play();
      console.log('Player reinitialized successfully');
    } catch (error) {
      console.warn('Error reinitializing player:', error);
    }
  }, []);

  useEffect(() => {
    console.log('App component mounted');
    console.log('Available Native Modules:', Object.keys(NativeModules));
    console.log('UnifiedPlayer module:', NativeModules.UnifiedPlayer);

    const progressCheckTimer = setTimeout(() => {
      if (!progressEventsReceived) {
        console.warn('No progress events received after 5 seconds');
        reinitializePlayer();
      }
    }, 5000);

    return () => {
      clearTimeout(progressCheckTimer);
      console.log('App component unmounted');
    };
  }, [progressEventsReceived, reinitializePlayer]);

  const handleProgress = (data: { currentTime: number; duration: number }) => {
    if (data.duration > 0) {
      setCurrentTime(data.currentTime);
      setDuration(data.duration);
      lastProgressTimeRef.current = data.currentTime;
      lastDurationRef.current = data.duration;
      if (!progressEventsReceived) {
        setProgressEventsReceived(true);
        console.log('Progress events are being received with valid data');
      }
    }
  };

  const handleLoadStart = () => {
    console.log(`Event: ${UnifiedPlayerEventTypes.LOAD_START}`);
    setIsPlayerReady(false);
    setProgressEventsReceived(false);
    setCurrentTime(0);
    setDuration(0);
  };

  const handleReadyToPlay = () => {
    console.log(`Event: ${UnifiedPlayerEventTypes.READY}`);
    setIsPlayerReady(true);
    if (autoplay) {
      setTimeout(async () => {
        try {
          console.log('Auto-playing video');
          await playerRef.current?.play();
        } catch (error) {
          console.warn('Auto-play failed:', error);
        }
      }, 500);
    }
  };

  const handleError = (error: PlayerError) => {
    console.error(`Event: ${UnifiedPlayerEventTypes.ERROR}`, error);
    Alert.alert('Player Error', `${error.code}: ${error.message}`);
  };

  const handlePlaybackComplete = async () => {
    console.log(`Event: ${UnifiedPlayerEventTypes.COMPLETE}`);
    if (loop) {
      console.log('Video ended, looping');
      try {
        await playerRef.current?.seekTo(0);
        await playerRef.current?.play();
      } catch (error) {
        console.warn('Loop failed:', error);
      }
    }
  };

  const handleFullscreenChanged = (fullscreen: boolean) => {
    console.log('Fullscreen state changed:', fullscreen);
    setIsFullscreen(fullscreen);
  };

  const handleToggleFullscreen = async () => {
    const newState = !isFullscreen;
    try {
      await playerRef.current?.toggleFullscreen(newState);
      setIsFullscreen(newState);
    } catch (error) {
      Alert.alert('Fullscreen Error', String(error));
    }
  };

  const handleCapture = async () => {
    try {
      const base64 = await playerRef.current?.capture();
      if (base64) setCapturedImage(`data:image/png;base64,${base64}`);
    } catch (error) {
      Alert.alert('Capture Error', String(error));
    }
  };

  const requestStoragePermissions = async () => {
    if (Platform.OS !== 'android') return true;
    try {
      if (Platform.Version >= 33) {
        const result = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.READ_MEDIA_VIDEO
        );
        return result === PermissionsAndroid.RESULTS.GRANTED;
      } else if (Platform.Version >= 29) {
        return true;
      } else {
        const granted = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
          PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE,
        ]);
        return (
          granted[PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE] ===
            PermissionsAndroid.RESULTS.GRANTED &&
          granted[PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE] ===
            PermissionsAndroid.RESULTS.GRANTED
        );
      }
    } catch {
      return false;
    }
  };

  const handleStartRecording = async () => {
    if (isRecording) {
      Alert.alert('Recording', 'Recording is already in progress');
      return;
    }
    if (!isPlayerReady || !progressEventsReceived) {
      Alert.alert('Cannot Record', 'The player is not ready yet.');
      return;
    }
    if (!(await requestStoragePermissions())) {
      Alert.alert('Permission Denied', 'Storage permissions are required');
      return;
    }
    try {
      const result = await playerRef.current?.startRecording();
      if (result) {
        setIsRecording(true);
        Alert.alert('Recording', 'Recording started successfully');
      } else {
        Alert.alert('Recording Error', 'Failed to start recording');
      }
    } catch (error) {
      Alert.alert('Recording Error', String(error));
    }
  };

  const handleStopRecording = async () => {
    if (!isRecording) {
      Alert.alert('Recording', 'No recording in progress');
      return;
    }
    try {
      const filePath = await playerRef.current?.stopRecording();
      setIsRecording(false);
      if (filePath && filePath.length > 0) {
        setRecordedVideoPath(filePath);
        Alert.alert('Recording Completed', `Video saved to: ${filePath}`);
      } else {
        Alert.alert('Recording Error', 'Failed to save recording');
      }
    } catch (error) {
      Alert.alert('Recording Error', String(error));
      setIsRecording(false);
    }
  };

  const handlePlay = async () => {
    try {
      await playerRef.current?.play();
      setIsPaused(false);
    } catch (error) {
      Alert.alert('Play Error', String(error));
    }
  };

  const handlePause = async () => {
    try {
      await playerRef.current?.pause();
      setIsPaused(true);
    } catch (error) {
      Alert.alert('Pause Error', String(error));
    }
  };

  const handleSeekTo = async (time: number) => {
    if (!progressEventsReceived) {
      Alert.alert('Cannot Seek', 'The player is not ready yet.');
      return;
    }
    try {
      const wasPlaying = !isPaused;
      if (wasPlaying) await playerRef.current?.pause();
      await playerRef.current?.seekTo(time);
      if (wasPlaying) await playerRef.current?.play();
    } catch (error) {
      Alert.alert('Seek Error', String(error));
    }
  };

  const handleGetCurrentTime = async () => {
    if (!progressEventsReceived) {
      Alert.alert('Cannot Get Time', 'The player is not ready yet.');
      return;
    }
    try {
      const nativeTime = await playerRef.current?.getCurrentTime();
      const time =
        nativeTime && nativeTime > 0 ? nativeTime : lastProgressTimeRef.current;
      Alert.alert('Current Time', `${time.toFixed(2)} seconds`);
    } catch (error) {
      Alert.alert('Error', `Failed to get current time: ${error}`);
    }
  };

  const handleGetDuration = async () => {
    if (!progressEventsReceived) {
      Alert.alert('Cannot Get Duration', 'The player is not ready yet.');
      return;
    }
    try {
      const nativeDuration = await playerRef.current?.getDuration();
      const dur =
        nativeDuration && nativeDuration > 0
          ? nativeDuration
          : lastDurationRef.current;
      Alert.alert('Duration', `${dur.toFixed(2)} seconds`);
    } catch (error) {
      Alert.alert('Error', `Failed to get duration: ${error}`);
    }
  };

  const handlePlayRecordedVideo = () => {
    if (!recordedVideoPath) return;
    let path = recordedVideoPath;
    if (Platform.OS === 'android' && !path.startsWith('file://')) {
      path = `file://${path}`;
    }
    setIsPlayerReady(false);
    setProgressEventsReceived(false);
    setCurrentVideoSource(singleVideoUrl);
    setTimeout(() => {
      setCurrentVideoSource(path);
      Alert.alert('Loading Video', 'Attempting to play the recorded video...');
    }, 1000);
  };

  const handleResetPlayer = () => {
    setCurrentVideoSource(singleVideoUrl);
    Alert.alert('Reset', 'Player reset to original video');
  };

  if (showSimpleExample) {
    return <SimpleExample onSwitchToFull={() => setShowSimpleExample(false)} />;
  }

  const playerProps = {
    ref: playerRef,
    videoUrl: currentVideoSource,
    thumbnailUrl,
    autoplay,
    loop,
    isPaused,
    isFullscreen,
    onLoadStart: handleLoadStart,
    onReadyToPlay: handleReadyToPlay,
    onError: handleError,
    onProgress: handleProgress,
    onPlaybackComplete: handlePlaybackComplete,
    onPlaybackStalled: () =>
      console.log(`Event: ${UnifiedPlayerEventTypes.STALLED}`),
    onPlaybackResumed: () =>
      console.log(`Event: ${UnifiedPlayerEventTypes.RESUMED}`),
    onPlaying: () => console.log(`Event: ${UnifiedPlayerEventTypes.PLAYING}`),
    onPaused: () => console.log(`Event: ${UnifiedPlayerEventTypes.PAUSED}`),
    onFullscreenChanged: handleFullscreenChanged,
  };

  if (isFullscreen) {
    return (
      <View style={styles.flexContainer}>
        <UnifiedPlayerView {...playerProps} style={styles.fullscreenPlayer} />
        <TouchableOpacity
          style={styles.exitFullscreenButton}
          onPress={handleToggleFullscreen}
        >
          <Text style={styles.exitFullscreenButtonText}>✕</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.flexContainer}>
      <ScrollView contentContainerStyle={styles.container}>
        <View style={styles.header}>
          <Text style={styles.title}>Full Example</Text>
          <ControlButton
            title="Simple Example"
            onPress={() => setShowSimpleExample(true)}
            variant="secondary"
          />
        </View>

        <UnifiedPlayerView {...playerProps} style={styles.player} />

        <View style={styles.controls}>
          <Text style={styles.sourceText} numberOfLines={1}>
            Source: {currentVideoSource}
          </Text>

          <ProgressDisplay
            currentTime={currentTime}
            duration={duration}
            isReady={isPlayerReady}
            isReceivingEvents={progressEventsReceived}
          />

          <PlayerControls
            onPlay={handlePlay}
            onPause={handlePause}
            onSeek={handleSeekTo}
            seekTime={10}
            seekLabel="Seek 10s"
          />

          <View style={styles.buttonRow}>
            <ControlButton
              title={isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen'}
              onPress={handleToggleFullscreen}
              variant={isFullscreen ? 'success' : 'primary'}
            />
          </View>

          <View style={styles.buttonRow}>
            <ControlButton
              title={`Autoplay: ${autoplay ? 'ON' : 'OFF'}`}
              onPress={() => setAutoplay(!autoplay)}
            />
            <ControlButton
              title={`Loop: ${loop ? 'ON' : 'OFF'}`}
              onPress={() => setLoop(!loop)}
            />
            <ControlButton
              title={`Paused: ${isPaused ? 'ON' : 'OFF'}`}
              onPress={() => setIsPaused(!isPaused)}
            />
          </View>

          <View style={styles.buttonRow}>
            <ControlButton
              title="Get Current Time"
              onPress={handleGetCurrentTime}
            />
            <ControlButton title="Get Duration" onPress={handleGetDuration} />
          </View>

          <View style={styles.buttonRow}>
            <ControlButton
              title="Reinitialize"
              onPress={reinitializePlayer}
              variant="secondary"
            />
            <ControlButton title="Capture" onPress={handleCapture} />
          </View>

          <RecordingControls
            isRecording={isRecording}
            onStartRecording={handleStartRecording}
            onStopRecording={handleStopRecording}
            recordedPath={recordedVideoPath}
            onPlayRecorded={handlePlayRecordedVideo}
            onReset={handleResetPlayer}
          />

          <CapturedFrame imageUri={capturedImage} />
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  flexContainer: {
    flex: 1,
    backgroundColor: '#000',
  },
  container: {
    flexGrow: 1,
    alignItems: 'center',
    backgroundColor: '#f0f0f0',
    paddingVertical: 20,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    width: '90%',
    marginBottom: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  player: {
    width: '90%',
    aspectRatio: 16 / 9,
    backgroundColor: 'black',
    marginBottom: 10,
  },
  fullscreenPlayer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    width: '100%',
    height: '100%',
    backgroundColor: '#000',
  },
  controls: {
    width: '90%',
    alignItems: 'center',
  },
  sourceText: {
    fontSize: 12,
    color: '#777',
    marginBottom: 5,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginVertical: 5,
  },
  exitFullscreenButton: {
    position: 'absolute',
    top: 40,
    right: 20,
    width: 40,
    height: 40,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
  },
  exitFullscreenButtonText: {
    color: '#fff',
    fontSize: 24,
    fontWeight: 'bold',
  },
});

export default App;
