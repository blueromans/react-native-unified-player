import { View, Text, StyleSheet } from 'react-native';

interface ProgressDisplayProps {
  currentTime?: number;
  duration?: number;
  isReady?: boolean;
  isReceivingEvents?: boolean;
}

export function ProgressDisplay({
  currentTime = 0,
  duration = 0,
  isReady,
  isReceivingEvents,
}: ProgressDisplayProps) {
  return (
    <View style={styles.container}>
      <Text style={styles.progressText}>
        {(currentTime ?? 0).toFixed(1)}s / {(duration ?? 0).toFixed(1)}s
      </Text>
      {isReady !== undefined && (
        <Text style={styles.statusText}>
          Status: {isReady ? 'Ready' : 'Loading'}
          {isReceivingEvents !== undefined &&
            ` | Events: ${isReceivingEvents ? 'Yes' : 'No'}`}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    marginVertical: 10,
  },
  progressText: {
    fontSize: 16,
    color: '#555',
    fontWeight: '500',
  },
  statusText: {
    fontSize: 14,
    color: '#777',
    marginTop: 4,
  },
});
