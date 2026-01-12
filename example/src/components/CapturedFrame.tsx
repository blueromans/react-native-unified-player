import { View, Text, Image, StyleSheet } from 'react-native';

interface CapturedFrameProps {
  imageUri: string | null;
  title?: string;
}

export function CapturedFrame({
  imageUri,
  title = 'Captured Frame',
}: CapturedFrameProps) {
  if (!imageUri) return null;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{title}</Text>
      <Image
        source={{ uri: imageUri }}
        style={styles.image}
        resizeMode="contain"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: 20,
    alignItems: 'center',
    width: '100%',
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#333',
  },
  image: {
    width: '100%',
    aspectRatio: 16 / 9,
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 5,
    backgroundColor: '#e0e0e0',
  },
});
