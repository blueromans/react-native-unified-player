import { Platform, UIManager } from 'react-native';

import VideoViewNativeComponent from '../../spec/fabric/VideoViewNativeComponent';

const LINKING_ERROR =
  `The package 'react-native-unified-player' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const ComponentName = 'RNCVideoView';

export const NativeVideoView =
  UIManager.getViewManagerConfig(ComponentName) != null
    ? VideoViewNativeComponent
    : () => {
        throw new Error(LINKING_ERROR);
      };
