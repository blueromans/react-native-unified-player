#import <UIKit/UIKit.h>
#import <React/RCTView.h>
#import <React/RCTComponent.h>
#import <MobileVLCKit/MobileVLCKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface UnifiedPlayerUIView : UIView <VLCMediaPlayerDelegate>

@property (nonatomic, strong) VLCMediaPlayer *player;
@property (nonatomic, copy, nullable) NSString *videoUrlString;
@property (nonatomic, copy, nullable) NSString *thumbnailUrlString;
@property (nonatomic, assign) BOOL autoplay;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, strong) NSArray *mediaOptions;
@property (nonatomic, weak) RCTBridge *bridge;
@property (nonatomic, assign) VLCMediaPlayerState previousState;
@property (nonatomic, assign) BOOL hasRenderedVideo;
@property (nonatomic, assign) BOOL readyEventSent;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferAdaptor;
@property (nonatomic, strong) NSString *recordingPath;
// We'll use associated objects instead of a property for CADisplayLink
@property (nonatomic, assign) NSInteger frameCount;

// Event callbacks
@property (nonatomic, copy) RCTDirectEventBlock onLoadStart;
@property (nonatomic, copy) RCTDirectEventBlock onReadyToPlay;
@property (nonatomic, copy) RCTDirectEventBlock onError;
@property (nonatomic, copy) RCTDirectEventBlock onProgress;
@property (nonatomic, copy) RCTDirectEventBlock onPlaybackComplete;
@property (nonatomic, copy) RCTDirectEventBlock onPlaybackStalled;
@property (nonatomic, copy) RCTDirectEventBlock onPlaybackResumed;
@property (nonatomic, copy) RCTDirectEventBlock onPlaying;
@property (nonatomic, copy) RCTDirectEventBlock onPaused;
@property (nonatomic, copy) RCTDirectEventBlock onFullscreenChanged;

// Method declarations
- (void)toggleFullscreen:(BOOL)fullscreen;
- (void)setupWithVideoUrlString:(nullable NSString *)videoUrlString;
- (void)setupThumbnailWithUrlString:(nullable NSString *)thumbnailUrlString;
- (void)play;
- (void)pause;
- (void)seekToTime:(NSNumber *)timeNumber;
- (float)getCurrentTime;
- (float)getDuration;
- (void)captureFrameWithCompletion:(void (^)(NSString * _Nullable base64String, NSError * _Nullable error))completion;
- (void)captureFrameForRecording;
- (BOOL)startRecordingToPath:(NSString *)outputPath;
- (void)startFrameCapture;
- (NSString *)stopRecording;

@end

NS_ASSUME_NONNULL_END
