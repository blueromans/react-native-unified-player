import { View, StyleSheet } from 'react-native';
import { ControlButton } from './ControlButton';

interface PlayerControlsProps {
  onPlay: () => void;
  onPause: () => void;
  onSeek?: (time: number) => void;
  seekTime?: number;
  seekLabel?: string;
}

export function PlayerControls({
  onPlay,
  onPause,
  onSeek,
  seekTime = 0,
  seekLabel = 'Restart',
}: PlayerControlsProps) {
  return (
    <View style={styles.container}>
      <ControlButton title="Play" onPress={onPlay} />
      <ControlButton title="Pause" onPress={onPause} />
      {onSeek && (
        <ControlButton title={seekLabel} onPress={() => onSeek(seekTime)} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginVertical: 10,
  },
});
