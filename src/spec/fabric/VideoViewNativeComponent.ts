import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';
import type { ViewProps } from 'react-native';
import type { Int32 } from 'react-native/Libraries/Types/CodegenTypes';
import type { DirectEventHandler } from 'react-native/Libraries/Types/CodegenTypes';

type OnNitroIdChangeEvent = Readonly<{
  nitroId: Int32;
}>;

export interface NativeProps extends ViewProps {
  nitroId: Int32;
  onNitroIdChange?: DirectEventHandler<OnNitroIdChangeEvent>;
}

export default codegenNativeComponent<NativeProps>('RNCVideoView', {
  paperComponentName: 'RNCVideoView',
});
