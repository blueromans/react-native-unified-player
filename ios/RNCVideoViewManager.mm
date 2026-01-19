//
//  RNCVideoViewManager.mm
//  UnifiedPlayer
//

#import <React/RCTViewManager.h>
#import <React/RCTUIManager.h>

// Declare the VideoComponentView interface for property access
// We don't import the Swift header to avoid pulling in Nitro C++ bridge code
@interface VideoComponentView : UIView
@property (nonatomic, strong) NSNumber *nitroId;
@property (nonatomic, copy) void (^onNitroIdChange)(NSDictionary *body);
@end

@interface RNCVideoViewManager : RCTViewManager
@end

@implementation RNCVideoViewManager

RCT_EXPORT_MODULE(RNCVideoView)

- (UIView *)view
{
  Class videoViewClass = NSClassFromString(@"UnifiedPlayer.VideoComponentView");
  if (videoViewClass) {
    NSLog(@"[UnifiedPlayer] Found VideoComponentView class, creating view");
    UIView *view = [[videoViewClass alloc] init];
    NSLog(@"[UnifiedPlayer] Created VideoComponentView: %@", view);
    return view;
  }
  NSLog(@"[UnifiedPlayer] ERROR: VideoComponentView class not found!");
  return [[UIView alloc] init];
}

RCT_EXPORT_VIEW_PROPERTY(nitroId, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(onNitroIdChange, RCTDirectEventBlock)

@end
