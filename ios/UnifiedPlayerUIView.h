#import <UIKit/UIKit.h>
#import <React/RCTView.h>
#import <React/RCTComponent.h>
#import <React/RCTBridge.h>
#import <React/RCTViewManager.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@class AVPlayer;
@class AVPlayerLayer;
@class AVPlayerItem;

@interface UnifiedPlayerUIView : UIView

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong, nullable) AVPlayerItem *playerItem;
@property (nonatomic, strong, nullable) id timeObserverToken;
@property (nonatomic, copy, nullable) NSString *videoUrlString;
@property (nonatomic, copy, nullable) NSString *thumbnailUrlString;
@property (nonatomic, assign) BOOL autoplay;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, assign) float speed;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isFullscreen;
@property (nonatomic, strong) NSArray *mediaOptions;
@property (nonatomic, weak) RCTBridge *bridge;
@property (nonatomic, assign) BOOL hasRenderedVideo;
@property (nonatomic, assign) BOOL readyEventSent;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferAdaptor;
@property (nonatomic, strong) NSString *recordingPath;
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
- (void)setSpeed:(float)speed;
- (void)setLoop:(BOOL)loop;

@end

NS_ASSUME_NONNULL_END
