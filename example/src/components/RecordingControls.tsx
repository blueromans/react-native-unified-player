import { View, Text, StyleSheet } from 'react-native';
import { ControlButton } from './ControlButton';

interface RecordingControlsProps {
  isRecording: boolean;
  onStartRecording: () => void;
  onStopRecording: () => void;
  recordedPath?: string | null;
  onPlayRecorded?: () => void;
  onReset?: () => void;
}

export function RecordingControls({
  isRecording,
  onStartRecording,
  onStopRecording,
  recordedPath,
  onPlayRecorded,
  onReset,
}: RecordingControlsProps) {
  return (
    <View style={styles.container}>
      <View style={styles.buttonRow}>
        <ControlButton
          title="Start Recording"
          onPress={onStartRecording}
          disabled={isRecording}
          variant={isRecording ? 'danger' : 'primary'}
        />
        <ControlButton
          title="Stop Recording"
          onPress={onStopRecording}
          disabled={!isRecording}
        />
      </View>

      {isRecording && (
        <View style={styles.statusContainer}>
          <Text style={styles.recordingText}>Recording in progress...</Text>
        </View>
      )}

      {recordedPath && !isRecording && (
        <View style={styles.recordedContainer}>
          <Text style={styles.recordedTitle}>Recording Saved:</Text>
          <Text style={styles.recordedPath}>{recordedPath}</Text>
          {(onPlayRecorded || onReset) && (
            <View style={styles.buttonRow}>
              {onPlayRecorded && (
                <ControlButton title="Play Recorded" onPress={onPlayRecorded} />
              )}
              {onReset && (
                <ControlButton
                  title="Reset"
                  onPress={onReset}
                  variant="secondary"
                />
              )}
            </View>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: '100%',
    alignItems: 'center',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginVertical: 10,
  },
  statusContainer: {
    marginTop: 10,
    padding: 10,
    backgroundColor: 'rgba(220, 53, 69, 0.2)',
    borderRadius: 5,
    width: '100%',
    alignItems: 'center',
  },
  recordingText: {
    color: '#dc3545',
    fontWeight: 'bold',
  },
  recordedContainer: {
    marginTop: 10,
    width: '100%',
    alignItems: 'center',
  },
  recordedTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 5,
  },
  recordedPath: {
    fontSize: 12,
    color: '#555',
    textAlign: 'center',
    padding: 10,
    backgroundColor: '#f8f9fa',
    borderRadius: 5,
    borderWidth: 1,
    borderColor: '#ddd',
    width: '100%',
    marginBottom: 10,
  },
});
