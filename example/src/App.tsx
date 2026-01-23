import React, { useState, useCallback } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import Slider from '@react-native-community/slider';
import { UnifiedPlayerView, useVideoPlayer } from 'react-native-unified-player';

const singleVideoUrl =
  'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_1MB.mp4';

const PLAYBACK_SPEEDS = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

function App(): React.JSX.Element {
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState(1.0);
  const [isSeeking, setIsSeeking] = useState(false);
  const [seekValue, setSeekValue] = useState(0);

  const player = useVideoPlayer({ uri: singleVideoUrl }, (p) => {
    p.loop = true;
    p.addEventListener('onProgress', (progress) => {
      if (!isSeeking) {
        setCurrentTime(progress.currentTime);
        setDuration(progress.duration);
      }
    });
    p.addEventListener('onPlaybackStateChange', (state) => {
      setIsPlaying(state.isPlaying);
    });
    p.addEventListener('onError', (error) => {
      Alert.alert('Player Error', `${error.code}: ${error.message}`);
    });
    p.addEventListener('onEnd', () => {
      console.log('Playback ended');
    });
  });

  const handleTogglePlayPause = useCallback(() => {
    if (player.isPlaying) {
      player.pause();
    } else {
      player.play();
    }
  }, [player]);

  const handleSeekBackward = useCallback(() => {
    const newTime = Math.max(0, player.currentTime - 10);
    player.seekTo(newTime);
  }, [player]);

  const handleSeekForward = useCallback(() => {
    const newTime = Math.min(player.duration, player.currentTime + 10);
    player.seekTo(newTime);
  }, [player]);

  const handleToggleFullscreen = useCallback(() => {
    setIsFullscreen((prev) => !prev);
  }, []);

  const handleSliderValueChange = useCallback((value: number) => {
    setSeekValue(value);
  }, []);

  const handleSliderSlidingStart = useCallback(() => {
    setIsSeeking(true);
  }, []);

  const handleSliderSlidingComplete = useCallback(
    (value: number) => {
      player.seekTo(value);
      setCurrentTime(value);
      setIsSeeking(false);
    },
    [player]
  );

  const handleSpeedChange = useCallback(
    (speed: number) => {
      player.rate = speed;
      setPlaybackSpeed(speed);
    },
    [player]
  );

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.title}>Unified Player Example</Text>

        <View style={styles.playerContainer}>
          <UnifiedPlayerView
            player={player}
            style={styles.player}
            controls={false}
            resizeMode="contain"
            fullscreen={isFullscreen}
            onFullscreenChange={setIsFullscreen}
          />
        </View>

        <View style={styles.progressContainer}>
          <View style={styles.sliderContainer}>
            <Text style={styles.timeText}>
              {formatTime(isSeeking ? seekValue : currentTime)}
            </Text>
            <Slider
              style={styles.slider}
              minimumValue={0}
              maximumValue={duration > 0 ? duration : 1}
              value={isSeeking ? seekValue : currentTime}
              onValueChange={handleSliderValueChange}
              onSlidingStart={handleSliderSlidingStart}
              onSlidingComplete={handleSliderSlidingComplete}
              minimumTrackTintColor="#007AFF"
              maximumTrackTintColor="#CCCCCC"
              thumbTintColor="#007AFF"
            />
            <Text style={styles.timeText}>{formatTime(duration)}</Text>
          </View>
        </View>

        <View style={styles.controls}>
          <TouchableOpacity
            style={styles.controlButton}
            onPress={handleSeekBackward}
          >
            <Text style={styles.controlButtonText}>-10s</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.controlButton, styles.playButton]}
            onPress={handleTogglePlayPause}
          >
            <Text style={styles.controlButtonText}>
              {player.isPlaying ? 'Pause' : 'Play'}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.controlButton}
            onPress={handleSeekForward}
          >
            <Text style={styles.controlButtonText}>+10s</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.speedContainer}>
          <Text style={styles.speedLabel}>Playback Speed:</Text>
          <View style={styles.speedButtonsRow}>
            {PLAYBACK_SPEEDS.map((speed) => (
              <TouchableOpacity
                key={speed}
                style={[
                  styles.speedButton,
                  playbackSpeed === speed && styles.speedButtonActive,
                ]}
                onPress={() => handleSpeedChange(speed)}
              >
                <Text
                  style={[
                    styles.speedButtonText,
                    playbackSpeed === speed && styles.speedButtonTextActive,
                  ]}
                >
                  {speed}x
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        <View style={styles.buttonRow}>
          <TouchableOpacity
            style={styles.actionButton}
            onPress={handleToggleFullscreen}
          >
            <Text style={styles.actionButtonText}>
              {isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen'}
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.statusContainer}>
          <Text style={styles.statusText}>
            Status: {isPlaying ? 'Playing' : 'Paused'}
          </Text>
          <Text style={styles.statusText}>Speed: {playbackSpeed}x</Text>
          <Text style={styles.statusText}>
            Loop: {player.loop ? 'On' : 'Off'}
          </Text>
          <Text style={styles.statusText}>Volume: {player.volume}</Text>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f0f0f0',
  },
  scrollContent: {
    flexGrow: 1,
    alignItems: 'center',
    paddingVertical: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 20,
  },
  playerContainer: {
    width: '90%',
    aspectRatio: 16 / 9,
    backgroundColor: 'black',
    marginBottom: 20,
    borderRadius: 8,
    overflow: 'hidden',
  },
  player: {
    flex: 1,
  },
  progressContainer: {
    width: '90%',
    marginBottom: 20,
  },
  sliderContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
  },
  slider: {
    flex: 1,
    height: 40,
    marginHorizontal: 8,
  },
  timeText: {
    fontSize: 12,
    color: '#666',
    minWidth: 45,
    textAlign: 'center',
  },
  progressText: {
    fontSize: 16,
    color: '#666',
  },
  controls: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
  },
  controlButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    marginHorizontal: 8,
  },
  playButton: {
    backgroundColor: '#34C759',
  },
  controlButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 20,
  },
  actionButton: {
    backgroundColor: '#5856D6',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    marginHorizontal: 8,
  },
  actionButtonText: {
    color: 'white',
    fontSize: 14,
    fontWeight: '600',
  },
  speedContainer: {
    width: '90%',
    marginBottom: 20,
    alignItems: 'center',
  },
  speedLabel: {
    fontSize: 14,
    color: '#333',
    fontWeight: '600',
    marginBottom: 10,
  },
  speedButtonsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 8,
  },
  speedButton: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 6,
    backgroundColor: '#E5E5E5',
    minWidth: 50,
    alignItems: 'center',
  },
  speedButtonActive: {
    backgroundColor: '#007AFF',
  },
  speedButtonText: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  speedButtonTextActive: {
    color: 'white',
  },
  statusContainer: {
    width: '90%',
    backgroundColor: 'white',
    padding: 16,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  statusText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
});

export default App;
