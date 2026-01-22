import { requireNativeComponent, type ViewProps } from 'react-native';
import type { HostComponent } from 'react-native';

type OnNitroIdChangeEvent = Readonly<{
  nitroId: number;
}>;

export interface ViewViewNativeProps extends ViewProps {
  nitroId: number;
  onNitroIdChange?: (event: { nativeEvent: OnNitroIdChangeEvent }) => void;
}

export default requireNativeComponent<ViewViewNativeProps>(
  'RNCVideoView'
) as HostComponent<ViewViewNativeProps>;
