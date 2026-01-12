#import <React/RCTViewManager.h>
#import <React/RCTLog.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTUIManager.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManagerUtils.h>
#import <React/RCTComponent.h>
#import <MobileVLCKit/MobileVLCKit.h>
#import <objc/runtime.h>
#import "UnifiedPlayerModule.h"
#import "UnifiedPlayerUIView.h"

// Main player view implementation
@implementation UnifiedPlayerUIView {
    UIImageView *_thumbnailImageView;
    CGRect _originalFrame;
    UIView *_originalSuperview;
    NSUInteger _originalIndex;
    UIView *_fullscreenContainer;
}

- (instancetype)init {
    if ((self = [super init])) {
        RCTLogInfo(@"[UnifiedPlayerViewManager] Initializing player view");

        // Initialize properties
        _hasRenderedVideo = NO;
        _readyEventSent = NO;

        // Create the player
        _player = [[VLCMediaPlayer alloc] init];
        _player.delegate = self;


        // Make sure we're visible and properly laid out
        self.backgroundColor = [UIColor blackColor];
        self.opaque = YES;
        self.userInteractionEnabled = YES;

        // Important: Enable content mode to scale properly
        self.contentMode = UIViewContentModeScaleAspectFit;
        self.clipsToBounds = YES;

        // Create thumbnail image view
        _thumbnailImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailImageView.clipsToBounds = YES;
        _thumbnailImageView.hidden = YES;
        [self addSubview:_thumbnailImageView];

        // After the view is fully initialized, set it as the drawable
        _player.drawable = self;

        _autoplay = YES;
        _loop = NO;
        _isFullscreen = NO;

        // Add notification for app entering background
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        // Add notification for app entering foreground
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

// Override drawRect to ensure our rendering context is set up without recursion
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    // This can sometimes help with VLC rendering issues
    // But check if we need to do this to avoid unnecessary work
    if (_player && _player.drawable != self) {
        _player.drawable = self;
        // Do not call any methods that would trigger layoutSubviews or drawRect again
    }
}

// Override layoutSubviews with safer implementation to avoid recursion
- (void)layoutSubviews {
    [super layoutSubviews];

    // Check bounds without using NSStringFromCGRect (which can cause recursion)
    CGRect bounds = self.bounds;

    // Only update if we have valid bounds and a player
    if (bounds.size.width > 0 && bounds.size.height > 0 && _player) {
        // Ensure drawable is set but don't call any methods that could cause recursion
        if (_player.drawable != self) {
            _player.drawable = self;
        }

        // Let VLC know the size has changed but don't force any redraws here
        // This may be VLC-specific and not required for all implementations
    }

    // Update thumbnail image view frame
    if (_thumbnailImageView) {
        _thumbnailImageView.frame = bounds;
    }
}

- (void)setupThumbnailWithUrlString:(nullable NSString *)thumbnailUrlString {
    RCTLogInfo(@"[UnifiedPlayerViewManager] setupThumbnailWithUrlString: %@", thumbnailUrlString);

    if (!thumbnailUrlString || [thumbnailUrlString length] == 0) {
        // Hide thumbnail if URL is empty
        _thumbnailImageView.hidden = YES;
        return;
    }

    // Make sure thumbnail view is properly sized
    _thumbnailImageView.frame = self.bounds;

    // Show the thumbnail view
    _thumbnailImageView.hidden = NO;

    // Load the image from URL
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *imageURL = [NSURL URLWithString:thumbnailUrlString];
        if (!imageURL) {
            // Try with encoding if the original URL doesn't work
            NSString *escapedString = [thumbnailUrlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            imageURL = [NSURL URLWithString:escapedString];

            if (!imageURL) {
                RCTLogError(@"[UnifiedPlayerViewManager] Invalid thumbnail URL format");
                dispatch_async(dispatch_get_main_queue(), ^{
                    self->_thumbnailImageView.hidden = YES;
                });
                return;
            }
        }

        NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
        if (imageData) {
            UIImage *image = [UIImage imageWithData:imageData];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self->_thumbnailImageView.image = image;
                    self->_thumbnailImageView.hidden = NO;
                });
            } else {
                RCTLogError(@"[UnifiedPlayerViewManager] Failed to create image from data");
                dispatch_async(dispatch_get_main_queue(), ^{
                    self->_thumbnailImageView.hidden = YES;
                });
            }
        } else {
            RCTLogError(@"[UnifiedPlayerViewManager] Failed to load image data from URL");
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_thumbnailImageView.hidden = YES;
            });
        }
    });
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    RCTLogInfo(@"[UnifiedPlayerViewManager] View moved to superview: %@", self.superview);

    // Sometimes VLC needs a reset of the drawable when moving to a superview
    if (_player) {
        _player.drawable = nil;
        _player.drawable = self;
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    RCTLogInfo(@"[UnifiedPlayerViewManager] View moved to window: %@", self.window);

    // Ensure proper rendering when window changes
    if (_player) {
        _player.drawable = nil;
        _player.drawable = self;
    }
}

- (void)appDidEnterBackground:(NSNotification *)notification {
    if (_player.isPlaying) {
        [_player pause];
    }
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    // Optionally resume playback when app becomes active again
    // if (wasPlayingBeforeBackground) {
    //    [_player play];
    // }
}

- (void)sendProgressEvent:(float)currentTime duration:(float)duration {
    if (self.onProgress) {
        self.onProgress(@{
            @"currentTime": @(currentTime),
            @"duration": @(duration)
        });
    }
}

- (void)sendEvent:(NSString *)eventName body:(NSDictionary *)body {
    // Direct event dispatch based on event name
    RCTDirectEventBlock handler = nil;

    if ([eventName isEqualToString:@"onLoadStart"]) {
        handler = self.onLoadStart;
    } else if ([eventName isEqualToString:@"onReadyToPlay"]) {
        handler = self.onReadyToPlay;
    } else if ([eventName isEqualToString:@"onError"]) {
        handler = self.onError;
    } else if ([eventName isEqualToString:@"onProgress"]) {
        handler = self.onProgress;
    } else if ([eventName isEqualToString:@"onPlaybackComplete"]) {
        handler = self.onPlaybackComplete;
    } else if ([eventName isEqualToString:@"onPlaybackStalled"]) {
        handler = self.onPlaybackStalled;
    } else if ([eventName isEqualToString:@"onPlaybackResumed"]) {
        handler = self.onPlaybackResumed;
    } else if ([eventName isEqualToString:@"onPlaying"]) {
        handler = self.onPlaying;
    } else if ([eventName isEqualToString:@"onPaused"]) {
        handler = self.onPaused;
    } else if ([eventName isEqualToString:@"onFullscreenChanged"]) {
        handler = self.onFullscreenChanged;
    }

    if (handler) {
        handler(body);
    }
}

// Helper method to load a specific video source URL
- (void)loadVideoSource:(NSString *)urlString {
    RCTLogInfo(@"[UnifiedPlayerViewManager] loadVideoSource: %@", urlString);

    // Reset flags
    _hasRenderedVideo = NO;
    _readyEventSent = NO;

    // Make sure we're in the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // Check if URL is valid
        NSURL *videoURL = [NSURL URLWithString:urlString];
        if (!videoURL) {
            // Try with encoding if the original URL doesn't work
            NSString *escapedString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            videoURL = [NSURL URLWithString:escapedString];

            if (!videoURL) {
                NSDictionary *errorInfo = @{
                    @"code": @"INVALID_URL",
                    @"message": @"Invalid URL format",
                    @"details": urlString ?: @""
                };
                [self sendEvent:@"onError" body:errorInfo];
                return;
            }
            RCTLogInfo(@"[UnifiedPlayerViewManager] URL needed encoding: %@", videoURL.absoluteString);
        }

        RCTLogInfo(@"[UnifiedPlayerViewManager] Using URL: %@", videoURL.absoluteString);

        // Send onLoadStart event before loading starts
        [self sendEvent:@"onLoadStart" body:@{}]; // No index sent

        // Create VLC media options array
        NSMutableArray *mediaOptions = [NSMutableArray array];

        // Add default network caching options for streaming
        BOOL isStreaming = [videoURL.scheme hasPrefix:@"http"] ||
                           [videoURL.scheme hasPrefix:@"rtsp"] ||
                           [videoURL.scheme hasPrefix:@"rtmp"] ||
                           [videoURL.scheme hasPrefix:@"mms"];

        if (isStreaming) {
            if (![self->_mediaOptions containsObject:@"network-caching"]) {
                [mediaOptions addObject:@"--network-caching=1500"];
                [mediaOptions addObject:@"--live-caching=1500"];
                [mediaOptions addObject:@"--file-caching=1500"];
                [mediaOptions addObject:@"--disc-caching=300"];
                [mediaOptions addObject:@"--clock-jitter=0"];
                [mediaOptions addObject:@"--clock-synchro=0"];
            }
            [mediaOptions addObject:@"--rtsp-tcp"];
            [mediaOptions addObject:@"--ipv4-timeout=1000"];
            [mediaOptions addObject:@"--http-reconnect"];
        }

        // Add custom media options if provided
        if (self->_mediaOptions && self->_mediaOptions.count > 0) {
            for (NSString *option in self->_mediaOptions) {
                if ([option isKindOfClass:[NSString class]]) {
                    if ([option hasPrefix:@"--"]) {
                        [mediaOptions addObject:option];
                    } else {
                        [mediaOptions addObject:[NSString stringWithFormat:@"--%@", option]];
                    }
                }
            }
        }

        // Stop any existing playback first
        [self->_player stop];

        // Create VLC media with options
        VLCMedia *media = [VLCMedia mediaWithURL:videoURL];
        for (NSString *option in mediaOptions) {
            [media addOption:option];
        }

        // Parse media to get metadata (including duration)
        [media parseWithOptions:VLCMediaParseNetwork | VLCMediaFetchNetwork timeout:10000];

        // Set new media to player
        self->_player.media = media;
        self->_player.drawable = self;
        self->_player.videoAspectRatio = NULL; // Use default aspect ratio

        RCTLogInfo(@"[UnifiedPlayerViewManager] Media configured with options: %@, duration: %d ms", mediaOptions, media.length.intValue);

        // Use UIKit methods for layout/display updates
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [self setNeedsDisplay];

        // Start playback if autoplay is enabled and not paused
        if (self->_autoplay && !self->_isPaused) {
            [self->_player play];
            [self setNeedsDisplay];
        }
    });
}

// Setup video URL
- (void)setupWithVideoUrlString:(nullable NSString *)videoUrlString {
    RCTLogInfo(@"[UnifiedPlayerViewManager] setupWithVideoUrlString: %@", videoUrlString);
    _videoUrlString = [videoUrlString copy];

    if (videoUrlString && videoUrlString.length > 0) {
        [self loadVideoSource:videoUrlString];
    } else {
        [_player stop];
        _player.media = nil;
    }
}

- (void)play {
    if (_player.media) {
        // Make sure drawable is properly set before playing
        if (_player.drawable != self) {
            _player.drawable = self;
        }

        // Ensure video track is enabled if available
        if (_player.numberOfVideoTracks > 0 && _player.currentVideoTrackIndex == -1) {
            // Attempt to enable the first video track
            if (_player.videoTrackIndexes.count > 0) {
                NSNumber *videoTrackIndex = [_player.videoTrackIndexes firstObject];
                _player.currentVideoTrackIndex = [videoTrackIndex intValue];
                RCTLogInfo(@"[UnifiedPlayerViewManager] Enabling video track index: %@", videoTrackIndex);
            }
        }

        // Apply aspect ratio settings
        _player.videoAspectRatio = NULL; // Use default aspect ratio

        // Set scale mode for the VLC video output
        // Note: VLC has its own scaling which is separate from UIView contentMode
        _player.scaleFactor = 0.0; // Auto scale

        [_player play];

        // Use these methods instead of forceRedraw
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [self setNeedsDisplay];

        RCTLogInfo(@"[UnifiedPlayerViewManager] play called, drawable: %@, frame: %@",
                 _player.drawable, NSStringFromCGRect(self.frame));
    }
}

- (void)pause {
    [_player pause];
    RCTLogInfo(@"[UnifiedPlayerViewManager] pause called");
}

- (void)seekToTime:(NSNumber *)timeNumber {
    float time = [timeNumber floatValue];
    // VLC uses a 0-1 position value for seeking
    float duration = [self getDuration];
    float position = duration > 0 ? time / duration : 0;
    position = MAX(0, MIN(1, position)); // Ensure position is between 0 and 1

    [_player setPosition:position];
    RCTLogInfo(@"[UnifiedPlayerViewManager] Seek to %f (position: %f)", time, position);
}

- (float)getCurrentTime {
    if (_player) {
        return _player.time.intValue / 1000.0f;
    }
    return 0.0f;
}

- (float)getDuration {
    if (_player && _player.media) {
        float mediaDuration = _player.media.length.intValue / 1000.0f;

        // If media.length is not available yet, try to calculate from position and time
        if (mediaDuration <= 0 && _player.position > 0) {
            float currentTime = _player.time.intValue / 1000.0f;
            if (currentTime > 0) {
                mediaDuration = currentTime / _player.position;
            }
        }

        return mediaDuration;
    }
    return 0.0f;
}

- (void)setSpeed:(float)speed {
    if (_player) {
        BOOL wasPlaying = _player.isPlaying;
        RCTLogInfo(@"[UnifiedPlayerViewManager] setSpeed: %f (wasPlaying: %d)", speed, wasPlaying);

        // VLC's setRate can sometimes pause playback, so we need to handle this
        [_player setRate:speed];

        // If the player was playing before, make sure it continues playing
        if (wasPlaying && !_player.isPlaying) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!self->_player.isPlaying) {
                    [self->_player play];
                    RCTLogInfo(@"[UnifiedPlayerViewManager] Resumed playback after speed change");
                }
            });
        }
    }
}

- (void)captureFrameWithCompletion:(void (^)(NSString * _Nullable base64String, NSError * _Nullable error))completion {
    if (!_player || !_player.drawable) {
        NSError *error = [NSError errorWithDomain:@"UnifiedPlayerUIView" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Player not initialized"}];
        if (completion) {
            completion(nil, error);
        }
        return;
    }

    // Create a snapshot of the current view
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (!image) {
        NSError *error = [NSError errorWithDomain:@"UnifiedPlayerUIView" code:101 userInfo:@{NSLocalizedDescriptionKey: @"Failed to capture frame"}];
        if (completion) {
            completion(nil, error);
        }
        return;
    }

    // Convert to base64
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    NSString *base64String = [imageData base64EncodedStringWithOptions:0];

    if (completion) {
        completion(base64String, nil);
    }
}

- (BOOL)startRecordingToPath:(NSString *)outputPath {
    RCTLogInfo(@"[UnifiedPlayerViewManager] startRecordingToPath: %@", outputPath);

    if (_isRecording) {
        RCTLogError(@"[UnifiedPlayerViewManager] Recording is already in progress");
        return NO;
    }

    if (!_player || !_player.isPlaying) {
        RCTLogError(@"[UnifiedPlayerViewManager] Cannot start recording: Player is not playing");
        return NO;
    }

    // Store the recording path
    _recordingPath = [outputPath copy];

    // Create directory if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directory = [outputPath stringByDeletingLastPathComponent];
    if (![fileManager fileExistsAtPath:directory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            RCTLogError(@"[UnifiedPlayerViewManager] Failed to create directory: %@", error);
            return NO;
        }
    }

    // Set up AVAssetWriter
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    // Remove existing file if it exists
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:outputPath error:&error];
        if (error) {
            RCTLogError(@"[UnifiedPlayerViewManager] Failed to remove existing file: %@", error);
            return NO;
        }
    }

    NSError *error = nil;
    _assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        RCTLogError(@"[UnifiedPlayerViewManager] Failed to create asset writer: %@", error);
        return NO;
    }

    // Get video dimensions
    CGSize videoSize = _player.videoSize;
    if (videoSize.width <= 0 || videoSize.height <= 0) {
        // Use view size as fallback
        videoSize = self.bounds.size;
    }

    // Configure video settings
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @((int)videoSize.width),
        AVVideoHeightKey: @((int)videoSize.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(2000000), // 2 Mbps
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        }
    };

    // Create video input
    _assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    _assetWriterVideoInput.expectsMediaDataInRealTime = YES;

    if ([_assetWriter canAddInput:_assetWriterVideoInput]) {
        [_assetWriter addInput:_assetWriterVideoInput];
    } else {
        RCTLogError(@"[UnifiedPlayerViewManager] Cannot add video input to asset writer");
        return NO;
    }

    // Create a pixel buffer adaptor for writing pixel buffers
    NSDictionary *pixelBufferAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferWidthKey: @((int)videoSize.width),
        (NSString *)kCVPixelBufferHeightKey: @((int)videoSize.height),
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };

    _assetWriterPixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor
                                     assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_assetWriterVideoInput
                                     sourcePixelBufferAttributes:pixelBufferAttributes];

    // Start recording session
    if ([_assetWriter startWriting]) {
        [_assetWriter startSessionAtSourceTime:kCMTimeZero];
        _isRecording = YES;

        // Start a timer to capture frames
        [self startFrameCapture];

        RCTLogInfo(@"[UnifiedPlayerViewManager] Recording started successfully");
        return YES;
    } else {
        RCTLogError(@"[UnifiedPlayerViewManager] Failed to start writing: %@", _assetWriter.error);
        return NO;
    }
}

- (void)startFrameCapture {
    RCTLogInfo(@"[UnifiedPlayerViewManager] Frame capture started");

    // Create a CADisplayLink to capture frames at the screen refresh rate
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(captureFrameForRecording)];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    // Store the display link as an associated object
    objc_setAssociatedObject(self, "displayLinkKey", displayLink, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Initialize frame count
    _frameCount = 0;
}

- (void)captureFrameForRecording {
    if (!_isRecording || !_assetWriterVideoInput.isReadyForMoreMediaData) {
        return;
    }

    // Create a bitmap context to draw the current view
    CGSize size = _player.videoSize;
    if (size.width <= 0 || size.height <= 0) {
        size = self.bounds.size;
    }

    // Create a pixel buffer
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, _assetWriterPixelBufferAdaptor.pixelBufferPool, &pixelBuffer);

    if (status != kCVReturnSuccess || pixelBuffer == NULL) {
        RCTLogError(@"[UnifiedPlayerViewManager] Failed to create pixel buffer");
        return;
    }

    // Lock the pixel buffer
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    // Get the pixel buffer address
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);

    // Create a bitmap context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixelData,
                                                size.width,
                                                size.height,
                                                8,
                                                CVPixelBufferGetBytesPerRow(pixelBuffer),
                                                colorSpace,
                                                kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);

    // Draw the current view into the context
    UIGraphicsPushContext(context);
    [self.layer renderInContext:context];
    UIGraphicsPopContext();

    // Clean up
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);

    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    // Calculate the presentation time
    CMTime presentationTime = CMTimeMake(_frameCount, 30); // 30 fps

    // Append the pixel buffer to the asset writer
    if (![_assetWriterPixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime]) {
        RCTLogError(@"[UnifiedPlayerViewManager] Failed to append pixel buffer: %@", _assetWriter.error);
    }

    // Release the pixel buffer
    CVPixelBufferRelease(pixelBuffer);

    // Increment the frame count
    _frameCount++;
}

- (NSString *)stopRecording {
    RCTLogInfo(@"[UnifiedPlayerViewManager] stopRecording called");

    if (!_isRecording) {
        RCTLogError(@"[UnifiedPlayerViewManager] No recording in progress");
        return @"";
    }

    // Stop frame capture by stopping the display link
    CADisplayLink *displayLink = objc_getAssociatedObject(self, "displayLinkKey");
    if (displayLink) {
        [displayLink invalidate];
        objc_setAssociatedObject(self, "displayLinkKey", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // Finish writing
    [_assetWriterVideoInput markAsFinished];
    [_assetWriter finishWritingWithCompletionHandler:^{
        if (self->_assetWriter.status == AVAssetWriterStatusCompleted) {
            RCTLogInfo(@"[UnifiedPlayerViewManager] Recording completed successfully");
        } else {
            RCTLogError(@"[UnifiedPlayerViewManager] Recording failed: %@", self->_assetWriter.error);
        }

        // Clean up
        self->_assetWriter = nil;
        self->_assetWriterVideoInput = nil;
        self->_assetWriterPixelBufferAdaptor = nil;
        self->_isRecording = NO;
        self->_frameCount = 0;
    }];

    NSString *path = _recordingPath;
    _recordingPath = nil;

    return path;
}

- (void)setAutoplay:(BOOL)autoplay {
    _autoplay = autoplay;
}

- (void)setLoop:(BOOL)loop {
    _loop = loop;
}

- (void)setIsPaused:(BOOL)isPaused {
    if (_isPaused != isPaused) {
        _isPaused = isPaused;
        if (_player) {
            if (_isPaused && _player.isPlaying) {
                [_player pause];
                RCTLogInfo(@"[UnifiedPlayerViewManager] Paused via isPaused prop");
            } else if (!_isPaused && !_player.isPlaying) {
                [_player play];
                RCTLogInfo(@"[UnifiedPlayerViewManager] Played via isPaused prop");
            }
        }
    }
}

- (void)setIsFullscreen:(BOOL)isFullscreen {
    RCTLogInfo(@"[UnifiedPlayerViewManager] setIsFullscreen: %d", isFullscreen);
    [self toggleFullscreen:isFullscreen];
}

- (void)toggleFullscreen:(BOOL)fullscreen {
    if (_isFullscreen == fullscreen) {
        return; // Already in the requested state
    }

    _isFullscreen = fullscreen;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (fullscreen) {
            [self enterFullscreen];
        } else {
            [self exitFullscreen];
        }

        // Send event about fullscreen state change
        if (self.onFullscreenChanged) {
            self.onFullscreenChanged(@{@"isFullscreen": @(fullscreen)});
        }
    });
}

- (void)enterFullscreen {
    RCTLogInfo(@"[UnifiedPlayerViewManager] Entering fullscreen mode");

    // Get the key window
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow) {
        RCTLogError(@"[UnifiedPlayerViewManager] Cannot find key window");
        return;
    }

    // Save original frame and superview
    _originalFrame = self.frame;
    _originalSuperview = self.superview;
    _originalIndex = [self.superview.subviews indexOfObject:self];

    // Remove from current superview
    [self removeFromSuperview];

    // Add to window with fullscreen frame
    CGRect fullscreenFrame = keyWindow.bounds;
    self.frame = fullscreenFrame;
    [keyWindow addSubview:self];

    // Bring to front
    [keyWindow bringSubviewToFront:self];

    // Force landscape orientation
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    [UIViewController attemptRotationToDeviceOrientation];

    // Hide status bar
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];

    // Keep screen on during playback
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];

    // Set background color to black for better fullscreen experience
    self.backgroundColor = [UIColor blackColor];

    // Update player layout
    [self setNeedsLayout];
    [self layoutIfNeeded];

    // Re-attach the drawable to ensure video continues playing
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_player) {
            // Reset the drawable to ensure the video surface is properly connected
            _player.drawable = nil;
            _player.drawable = self;
            RCTLogInfo(@"[UnifiedPlayerViewManager] Re-attached drawable after entering fullscreen");
        }
    });
}

- (void)exitFullscreen {
    RCTLogInfo(@"[UnifiedPlayerViewManager] Exiting fullscreen mode");

    // Remove from window
    [self removeFromSuperview];

    // Restore to original superview
    if (_originalSuperview) {
        self.frame = _originalFrame;
        if (_originalIndex < _originalSuperview.subviews.count) {
            [_originalSuperview insertSubview:self atIndex:_originalIndex];
        } else {
            [_originalSuperview addSubview:self];
        }
    }

    // Restore portrait orientation
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    [UIViewController attemptRotationToDeviceOrientation];

    // Show status bar
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];

    // Allow screen to turn off
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];

    // Restore original background color
    self.backgroundColor = [UIColor blackColor];

    // Update player layout
    [self setNeedsLayout];
    [self layoutIfNeeded];

    // Re-attach the drawable to ensure video continues playing
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_player) {
            // Reset the drawable to ensure the video surface is properly connected
            _player.drawable = nil;
            _player.drawable = self;
            RCTLogInfo(@"[UnifiedPlayerViewManager] Re-attached drawable after exiting fullscreen");
        }
    });
}


#pragma mark - VLCMediaPlayerDelegate

- (void)mediaPlayerTimeChanged:(NSNotification *)notification {
    float currentTime = [self getCurrentTime];
    float duration = [self getDuration];

    // Avoid sending progress events for invalid durations
    if (duration > 0 && !isnan(duration)) {
        [self sendProgressEvent:currentTime duration:duration];
    }
    // RCTLogInfo(@"[UnifiedPlayerViewManager] mediaPlayerTimeChanged - CurrentTime: %f, Duration: %f", currentTime, duration); // Commented out for less noise
}

- (void)mediaPlayerStateChanged:(NSNotification *)notification {
    VLCMediaPlayerState state = _player.state;
    RCTLogInfo(@"[UnifiedPlayerViewManager] mediaPlayerStateChanged - New State: %d", state); // Added Log

    // Check if media is ready to play
    if ((state == VLCMediaPlayerStateBuffering || state == VLCMediaPlayerStatePlaying || state == VLCMediaPlayerStatePaused) && !_readyEventSent) {
        // Check if we have video tracks
        NSArray *videoTracks = [_player.media tracksInformation];
        if (videoTracks.count > 0 || _player.hasVideoOut) {
            RCTLogInfo(@"[UnifiedPlayerViewManager] Media is ready to play - Video tracks found: %lu", (unsigned long)videoTracks.count);

            // Send ready event when media is ready, regardless of autoplay
            [self sendEvent:@"onReadyToPlay" body:@{}];
            _readyEventSent = YES;
        }
    }

    // Debug information for video output
    if (state == VLCMediaPlayerStatePlaying) {
        RCTLogInfo(@"[UnifiedPlayerViewManager] Video size: %@",
                   NSStringFromCGSize(_player.videoSize));
        RCTLogInfo(@"[UnifiedPlayerViewManager] Has video out: %@",
                   _player.hasVideoOut ? @"YES" : @"NO");

        // Check video tracks
        NSArray *videoTracks = [_player.media tracksInformation];
        if (videoTracks.count > 0) {
            RCTLogInfo(@"[UnifiedPlayerViewManager] Video tracks found: %lu", (unsigned long)videoTracks.count);

            // Hide thumbnail when video starts playing
            if (_thumbnailImageView) {
                _thumbnailImageView.hidden = YES;
            }

            // Send playing event when we actually start playing
            [self sendEvent:@"onPlaying" body:@{}];

            // Trigger a delayed drawable update to help with rendering
            if (!_hasRenderedVideo && _player.videoSize.width > 0) {
                _hasRenderedVideo = YES;
                [self updatePlayerDrawableWithDelay];
            }
        } else {
            RCTLogInfo(@"[UnifiedPlayerViewManager] No video tracks found!");
        }
    }

    // Check for buffer state transitions
    if (_previousState == VLCMediaPlayerStateBuffering && state == VLCMediaPlayerStatePlaying) {
        // We've recovered from buffering
        [self sendEvent:@"onPlaybackResumed" body:@{}];
    }

    // Store the current state for future comparisons
    _previousState = state;

    // React to state changes
    switch (state) {
        case VLCMediaPlayerStateOpening:
            RCTLogInfo(@"[UnifiedPlayerViewManager] VLCMediaPlayerStateOpening");
            break;

        case VLCMediaPlayerStateBuffering:
            RCTLogInfo(@"[UnifiedPlayerViewManager] VLCMediaPlayerStateBuffering");
            [self sendEvent:@"onPlaybackStalled" body:@{}];
            break;

        case VLCMediaPlayerStatePlaying:
            RCTLogInfo(@"[UnifiedPlayerViewManager] VLCMediaPlayerStatePlaying");
            break;

        case VLCMediaPlayerStatePaused:
            RCTLogInfo(@"[UnifiedPlayerViewManager] VLCMediaPlayerStatePaused");
            [self sendEvent:@"onPaused" body:@{}];
            break;

        case VLCMediaPlayerStateStopped:
            RCTLogInfo(@"[UnifiedPlayerViewManager] VLCMediaPlayerStateStopped");
            // We don't emit onStopped event as it's not in our unified event list
            break;

        case VLCMediaPlayerStateEnded:
             RCTLogInfo(@"[UnifiedPlayerViewManager] VLCMediaPlayerStateEnded");
             // Send completion event. Looping/advancement will be handled in JS.
             [self sendEvent:@"onPlaybackComplete" body:@{}];
             // Simple loop handling
             if (_loop) {
                  RCTLogInfo(@"[UnifiedPlayerViewManager] Looping video (iOS)");
                  [_player stop];
                  [_player play];
             }
             break;

        case VLCMediaPlayerStateError:
            RCTLogInfo(@"[UnifiedPlayerViewManager] VLCMediaPlayerStateError");
            [self sendEvent:@"onError" body:@{
                @"code": @"PLAYBACK_ERROR",
                @"message": @"VLC player encountered an error",
                @"details": @{@"url": _videoUrlString ?: @""}
            }];
            break;

        default:
            break;
    }
}

- (void)mediaPlayerSnapshot:(NSNotification *)notification {
    // Handle snapshot completion if needed
}

- (void)mediaPlayerTitleChanged:(NSNotification *)notification {
    // Handle title changes if needed
}

// Define a method that maps VLC buffer state changes to appropriate RN events
- (void)handleBufferingStatusChange {
    if (_player.state == VLCMediaPlayerStateBuffering) {
        // When buffering, send stalled event
        [self sendEvent:@"onPlaybackStalled" body:@{}];
    } else if (_player.state == VLCMediaPlayerStatePlaying && _player.isPlaying) {
        // When buffer is full and playing again, send resumed event
        [self sendEvent:@"onPlaybackResumed" body:@{}];
    }
}

- (void)dealloc {
    RCTLogInfo(@"[UnifiedPlayerViewManager] Deallocating player view");

    // Remove all observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Stop recording if in progress
    if (_isRecording) {
        [self stopRecording];
    }

    // Clean up display link if it exists
    CADisplayLink *displayLink = objc_getAssociatedObject(self, "displayLinkKey");
    if (displayLink) {
        [displayLink invalidate];
        objc_setAssociatedObject(self, "displayLinkKey", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // Stop playback and release player
    [_player stop];
    _player.delegate = nil;
    _player = nil;
}

// Update updatePlayerDrawableWithDelay to use safer redraw approach
- (void)updatePlayerDrawableWithDelay {
    // Sometimes a slight delay can help with rendering issues
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_player) {
            // Reset drawable
            self->_player.drawable = nil;
            self->_player.drawable = self;

            // Call UIKit methods directly instead of forceRedraw
            [self setNeedsLayout];
            [self layoutIfNeeded];
            [self setNeedsDisplay];

            RCTLogInfo(@"[UnifiedPlayerViewManager] Drawable updated with delay");
        }
    });
}

@end

@interface UnifiedPlayerViewManager : RCTViewManager
@end

@implementation UnifiedPlayerViewManager

RCT_EXPORT_MODULE(UnifiedPlayerView)

@synthesize bridge = _bridge;

- (UIView *)view
{
    UnifiedPlayerUIView *playerView = [[UnifiedPlayerUIView alloc] init];
    playerView.bridge = self.bridge;
    return playerView;
}

// Video URL property
RCT_CUSTOM_VIEW_PROPERTY(videoUrl, NSString, UnifiedPlayerUIView)
{
    if ([json isKindOfClass:[NSString class]]) {
        [view setupWithVideoUrlString:(NSString *)json];
    } else if (json == nil || json == [NSNull null]) {
        [view setupWithVideoUrlString:nil];
    } else {
        RCTLogError(@"[UnifiedPlayerViewManager] Invalid type for videoUrl prop. Expected NSString.");
        [view setupWithVideoUrlString:nil];
    }
}

// Thumbnail URL property
RCT_CUSTOM_VIEW_PROPERTY(thumbnailUrl, NSString, UnifiedPlayerUIView)
{
    view.thumbnailUrlString = json;
    [view setupThumbnailWithUrlString:json];
}

// Autoplay property
RCT_CUSTOM_VIEW_PROPERTY(autoplay, BOOL, UnifiedPlayerUIView)
{
    view.autoplay = [RCTConvert BOOL:json];
}

// Loop property
RCT_CUSTOM_VIEW_PROPERTY(loop, BOOL, UnifiedPlayerUIView)
{
    view.loop = [RCTConvert BOOL:json];
}

// Media options property
RCT_CUSTOM_VIEW_PROPERTY(mediaOptions, NSArray, UnifiedPlayerUIView)
{
    view.mediaOptions = [RCTConvert NSArray:json];
}

// isPaused property
RCT_CUSTOM_VIEW_PROPERTY(isPaused, BOOL, UnifiedPlayerUIView)
{
    view.isPaused = [RCTConvert BOOL:json];
}

// isFullscreen property
RCT_CUSTOM_VIEW_PROPERTY(isFullscreen, BOOL, UnifiedPlayerUIView)
{
    view.isFullscreen = [RCTConvert BOOL:json];
}

// Event handlers
RCT_EXPORT_VIEW_PROPERTY(onLoadStart, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onReadyToPlay, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onProgress, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlaybackComplete, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlaybackStalled, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlaybackResumed, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlaying, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPaused, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onFullscreenChanged, RCTDirectEventBlock);

@end
