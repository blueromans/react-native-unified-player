import { useState, useRef } from 'react';
import { StyleSheet, View, Text, Alert } from 'react-native';
import {
  UnifiedPlayerView,
  type UnifiedPlayerRef,
} from 'react-native-unified-player';
import {
  ControlButton,
  PlayerControls,
  ProgressDisplay,
  CapturedFrame,
} from './components';

const VIDEO_URL =
  'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_1MB.mp4';

interface SimpleExampleProps {
  onSwitchToFull: () => void;
}

export function SimpleExample({ onSwitchToFull }: SimpleExampleProps) {
  const playerRef = useRef<UnifiedPlayerRef>(null);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [capturedImage, setCapturedImage] = useState<string | null>(null);

  const handleCapture = async () => {
    try {
      const base64 = await playerRef.current?.capture();
      if (base64) {
        setCapturedImage(`data:image/png;base64,${base64}`);
      }
    } catch (error) {
      Alert.alert('Capture Error', String(error));
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Simple Example</Text>
        <ControlButton
          title="Full Example"
          onPress={onSwitchToFull}
          variant="secondary"
        />
      </View>

      <UnifiedPlayerView
        ref={playerRef}
        videoUrl={VIDEO_URL}
        autoplay
        style={styles.player}
        onProgress={(data) => {
          setCurrentTime(data.currentTime);
          setDuration(data.duration);
        }}
      />

      <ProgressDisplay currentTime={currentTime} duration={duration} />

      <PlayerControls
        onPlay={() => playerRef.current?.play()}
        onPause={() => playerRef.current?.pause()}
        onSeek={(time) => playerRef.current?.seekTo(time)}
        seekTime={0}
        seekLabel="Restart"
      />

      <ControlButton title="Capture" onPress={handleCapture} />

      <CapturedFrame imageUri={capturedImage} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f0f0f0',
    padding: 20,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  player: {
    width: '100%',
    aspectRatio: 16 / 9,
    backgroundColor: 'black',
  },
});
