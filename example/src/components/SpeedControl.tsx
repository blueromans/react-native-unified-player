import { View, Text, StyleSheet } from 'react-native';
import { ControlButton } from './ControlButton';

interface SpeedControlProps {
  currentSpeed: number;
  onSpeedChange: (speed: number) => void;
}

const SPEED_OPTIONS = [1, 2, 4, 8];

export function SpeedControl({
  currentSpeed,
  onSpeedChange,
}: SpeedControlProps) {
  return (
    <View style={styles.container}>
      <Text style={styles.label}>Speed:</Text>
      <View style={styles.buttons}>
        {SPEED_OPTIONS.map((speed) => (
          <ControlButton
            key={speed}
            title={`${speed}x`}
            onPress={() => onSpeedChange(speed)}
            variant={currentSpeed === speed ? 'success' : 'primary'}
            style={styles.button}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 10,
  },
  label: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginRight: 10,
  },
  buttons: {
    flexDirection: 'row',
  },
  button: {
    paddingHorizontal: 12,
    marginHorizontal: 2,
  },
});
