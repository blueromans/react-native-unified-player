#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h> // Import MobileVLCKit

// Forward declaration for UnifiedPlayerUIView
@class UnifiedPlayerUIView;

@interface UnifiedPlayerModule : RCTEventEmitter <RCTBridgeModule>
@end
