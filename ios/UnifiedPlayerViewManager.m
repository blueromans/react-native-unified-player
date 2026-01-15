#import <React/RCTViewManager.h>
#import <React/RCTLog.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTUIManager.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManagerUtils.h>
#import <React/RCTComponent.h>
#import <React/RCTConvert.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
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
    UIViewController *_fullscreenViewController;
    UIButton *_fullscreenCloseButton;
    float _cachedDuration;
    BOOL _isObservingPlayerItem;
}

- (instancetype)init {
    if ((self = [super init])) {
        RCTLogInfo(@"[UnifiedPlayerViewManager] Initializing AVPlayer view");

        // Initialize properties
        _hasRenderedVideo = NO;
        _readyEventSent = NO;
        _cachedDuration = 0.0f;
        _speed = 1.0f; // Default playback speed
        _isObservingPlayerItem = NO;

        // Create the AVPlayer
        _player = [[AVPlayer alloc] init];
        
        // Create AVPlayerLayer for rendering
        _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
        _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        _playerLayer.frame = self.bounds;
        [self.layer addSublayer:_playerLayer];

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

        _autoplay = YES;
        _loop = NO;
        _isFullscreen = NO;
        
        // Add notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

        // Note: AVPlayerItemDidPlayToEndTimeNotification observer will be added when playerItem is created
        // Add time observer for progress updates
        [self setupTimeObserver];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    _playerLayer.frame = bounds;
    _thumbnailImageView.frame = bounds;
}

- (void)dealloc {
    RCTLogInfo(@"[UnifiedPlayerViewManager] Deallocating AVPlayer view");

    // Remove all observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Remove time observer
    if (_timeObserverToken) {
        [_player removeTimeObserver:_timeObserverToken];
        _timeObserverToken = nil;
    }
    
    // Remove KVO observers
    [self removePlayerItemObservers];

    // Stop recording if in progress
    if (_isRecording) {
        [self stopRecording];
    }

    // Clean up player
    [_player pause];
    _player = nil;
    _playerLayer = nil;
    _playerItem = nil;
}

#pragma mark - Helper Methods

- (void)sendProgressEvent:(float)currentTime duration:(float)duration {
    if (self.onProgress) {
        self.onProgress(@{
        @"currentTime": @(currentTime),
        @"duration": @(duration)
        });
    }
}

- (void)sendEvent:(NSString *)eventName body:(NSDictionary *)body {
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

- (void)setupTimeObserver {
    // Remove existing observer if any
    if (_timeObserverToken) {
        [_player removeTimeObserver:_timeObserverToken];
        _timeObserverToken = nil;
    }
    
    // Add time observer for progress updates (every 0.25 seconds)
    __weak typeof(self) weakSelf = self;
    CMTime interval = CMTimeMakeWithSeconds(0.25, NSEC_PER_SEC);
    _timeObserverToken = [_player addPeriodicTimeObserverForInterval:interval
                                                               queue:dispatch_get_main_queue()
                                                          usingBlock:^(CMTime time) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            float currentTime = CMTimeGetSeconds(time);
            float duration = [strongSelf getDuration];
            
            if (duration > 0 && !isnan(duration) && !isnan(currentTime)) {
                [strongSelf sendProgressEvent:currentTime duration:duration];
            }
        }
    }];
}

- (void)addPlayerItemObservers {
    if (!_playerItem || _isObservingPlayerItem) {
        return;
    }
    
    _isObservingPlayerItem = YES;
    
    // Observe status changes
    [_playerItem addObserver:self
                 forKeyPath:@"status"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
    
    // Observe playback buffer
    [_playerItem addObserver:self
                 forKeyPath:@"playbackBufferEmpty"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
    
    // Observe playback likely to keep up
    [_playerItem addObserver:self
                 forKeyPath:@"playbackLikelyToKeepUp"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
}

- (void)removePlayerItemObservers {
    if (!_playerItem || !_isObservingPlayerItem) {
        return;
    }
    
    _isObservingPlayerItem = NO;
    
    @try {
        [_playerItem removeObserver:self forKeyPath:@"status"];
        [_playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    } @catch (NSException *exception) {
        RCTLogWarn(@"[UnifiedPlayerViewManager] Error removing observers: %@", exception);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (object != _playerItem) {
        return;
    }
    
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = _playerItem.status;
        
        if (status == AVPlayerItemStatusReadyToPlay) {
            RCTLogInfo(@"[UnifiedPlayerViewManager] AVPlayerItem ready to play");
            
            // Cache duration
            CMTime duration = _playerItem.duration;
            if (CMTIME_IS_VALID(duration) && !CMTIME_IS_INDEFINITE(duration)) {
                _cachedDuration = CMTimeGetSeconds(duration);
                RCTLogInfo(@"[UnifiedPlayerViewManager] Cached duration: %f seconds", _cachedDuration);
            }
            
            // Send ready event if not already sent
            if (!_readyEventSent) {
                [self sendEvent:@"onReadyToPlay" body:@{}];
                _readyEventSent = YES;
            }
            
            // Hide thumbnail when ready
            if (_thumbnailImageView) {
                _thumbnailImageView.hidden = YES;
            }
            
            // Start playback if autoplay is enabled
            if (_autoplay && !_isPaused) {
                [self play];
            }
        } else if (status == AVPlayerItemStatusFailed) {
            RCTLogError(@"[UnifiedPlayerViewManager] AVPlayerItem failed: %@", _playerItem.error);
            [self sendEvent:@"onError" body:@{
                @"code": @"PLAYBACK_ERROR",
                @"message": _playerItem.error.localizedDescription ?: @"Playback failed",
                @"details": @{@"url": _videoUrlString ?: @""}
            }];
        }
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        if (_playerItem.playbackBufferEmpty) {
            RCTLogInfo(@"[UnifiedPlayerViewManager] Playback buffer empty - stalling");
            [self sendEvent:@"onPlaybackStalled" body:@{}];
        }
    } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if (_playerItem.playbackLikelyToKeepUp) {
            RCTLogInfo(@"[UnifiedPlayerViewManager] Playback likely to keep up - resumed");
            [self sendEvent:@"onPlaybackResumed" body:@{}];
        }
    }
}

#pragma mark - Video Loading

- (void)loadVideoSource:(NSString *)urlString {
    RCTLogInfo(@"[UnifiedPlayerViewManager] loadVideoSource: %@", urlString);

    // Reset flags
    _hasRenderedVideo = NO;
    _readyEventSent = NO;
    _cachedDuration = 0.0f;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Check if URL is valid
        NSURL *videoURL = [NSURL URLWithString:urlString];
        if (!videoURL) {
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
        }

        RCTLogInfo(@"[UnifiedPlayerViewManager] Using URL: %@", videoURL.absoluteString);

        // Send onLoadStart event
        [self sendEvent:@"onLoadStart" body:@{}];

        // Remove old observers
        [self removePlayerItemObservers];
        
        // Remove old player item from notification center
        if (self->_playerItem) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:self->_playerItem];
        }

        // Create AVAsset
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        
        // Create AVPlayerItem
        self->_playerItem = [AVPlayerItem playerItemWithAsset:asset];
        
        // Replace current item
        [self->_player replaceCurrentItemWithPlayerItem:self->_playerItem];
        
        // Add observers
        [self addPlayerItemObservers];
        
        // Add notification observer for end of playback
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:self->_playerItem];
        
        // Apply playback speed if set
        if (self->_speed > 0 && self->_speed != 1.0f) {
            float validSpeed = MAX(0.25f, MIN(4.0f, self->_speed));
            self->_player.rate = validSpeed;
        }
        
        // Setup looping if enabled
        [self updateLooping];
    });
}

- (void)setupWithVideoUrlString:(nullable NSString *)videoUrlString {
    RCTLogInfo(@"[UnifiedPlayerViewManager] setupWithVideoUrlString: %@", videoUrlString);
    _videoUrlString = [videoUrlString copy];

    if (videoUrlString && videoUrlString.length > 0) {
        [self loadVideoSource:videoUrlString];
    } else {
        [_player pause];
        [_player replaceCurrentItemWithPlayerItem:nil];
        [self removePlayerItemObservers];
        _playerItem = nil;
    }
}

- (void)setupThumbnailWithUrlString:(nullable NSString *)thumbnailUrlString {
    if (!thumbnailUrlString || thumbnailUrlString.length == 0) {
        _thumbnailImageView.hidden = YES;
        return;
    }

    _thumbnailUrlString = [thumbnailUrlString copy];
    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailUrlString];
    
    if (thumbnailURL) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *imageData = [NSData dataWithContentsOfURL:thumbnailURL];
            if (imageData) {
                UIImage *image = [UIImage imageWithData:imageData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self->_thumbnailImageView.image = image;
                    self->_thumbnailImageView.hidden = NO;
                });
            }
        });
    }
}

#pragma mark - Playback Control

- (void)play {
    if (_playerItem && _playerItem.status == AVPlayerItemStatusReadyToPlay) {
        [_player play];
        
        // Apply speed AFTER play() is called to ensure it's not reset
        // Use a small delay to ensure play() has started
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->_speed > 0 && self->_speed != 1.0f) {
                float validSpeed = MAX(0.25f, MIN(4.0f, self->_speed));
                self->_player.rate = validSpeed;
                RCTLogInfo(@"[UnifiedPlayerViewManager] Applied speed: %f after play", validSpeed);
            } else {
                self->_player.rate = 1.0f;
            }
        });
        
        [self sendEvent:@"onPlaying" body:@{}];
        RCTLogInfo(@"[UnifiedPlayerViewManager] play called");
    } else {
        RCTLogWarn(@"[UnifiedPlayerViewManager] Cannot play - player item not ready");
    }
}

- (void)pause {
    [_player pause];
    [self sendEvent:@"onPaused" body:@{}];
    RCTLogInfo(@"[UnifiedPlayerViewManager] pause called");
}

- (void)seekToTime:(NSNumber *)timeNumber {
    float time = [timeNumber floatValue];
    
    if (_playerItem && _playerItem.status == AVPlayerItemStatusReadyToPlay) {
        CMTime seekTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
        CMTime duration = _playerItem.duration;
        
        // Ensure seek time is within bounds
        if (CMTIME_IS_VALID(duration) && CMTimeCompare(seekTime, duration) > 0) {
            seekTime = duration;
        }
        
        [_player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        RCTLogInfo(@"[UnifiedPlayerViewManager] Seek to %f seconds", time);
    }
}

- (float)getCurrentTime {
    if (_playerItem && _playerItem.status == AVPlayerItemStatusReadyToPlay) {
        CMTime currentTime = _player.currentTime;
        if (CMTIME_IS_VALID(currentTime)) {
            return CMTimeGetSeconds(currentTime);
        }
    }
    return 0.0f;
}

- (float)getDuration {
    if (_playerItem && _playerItem.status == AVPlayerItemStatusReadyToPlay) {
        CMTime duration = _playerItem.duration;
        if (CMTIME_IS_VALID(duration) && !CMTIME_IS_INDEFINITE(duration)) {
            float durationSeconds = CMTimeGetSeconds(duration);
            if (durationSeconds > 0) {
                _cachedDuration = durationSeconds;
                return durationSeconds;
            }
        }
    }
    
    // Return cached duration if available
    return _cachedDuration > 0 ? _cachedDuration : 0.0f;
}

- (void)setSpeed:(float)speed {
    _speed = speed;
    float validSpeed = MAX(0.25f, MIN(4.0f, speed));
    
    RCTLogInfo(@"[UnifiedPlayerViewManager] setSpeed: %f (valid: %f)", speed, validSpeed);
    
    if (_playerItem && _playerItem.status == AVPlayerItemStatusReadyToPlay) {
        if (_player.rate > 0) {
            // Player is playing, set rate directly
            _player.rate = validSpeed;
        } else {
            // Player is paused, rate will be applied on next play
        }
    }
}

- (void)updateLooping {
    // Note: AVPlayerLooper requires AVQueuePlayer, but switching players can be complex
    // For now, we'll handle looping manually via notification observer
    // This is simpler and more reliable for our use case
    RCTLogInfo(@"[UnifiedPlayerViewManager] Loop setting updated: %@", _loop ? @"YES" : @"NO");
}

- (void)setLoop:(BOOL)loop {
    _loop = loop;
    [self updateLooping];
}

#pragma mark - Notifications

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    RCTLogInfo(@"[UnifiedPlayerViewManager] Video ended, loop: %@, speed: %f", _loop ? @"YES" : @"NO", _speed);
        
    if (_loop) {
        // Store current speed before seeking
        float savedSpeed = _speed;
        
        // Seek to beginning and play again
            [_player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                if (finished) {
                    [self->_player play];
                // Restore playback speed AFTER play() is called
                // Use multiple attempts to ensure speed is set
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (savedSpeed > 0 && savedSpeed != 1.0f) {
                        float validSpeed = MAX(0.25f, MIN(4.0f, savedSpeed));
                        self->_player.rate = validSpeed;
                        RCTLogInfo(@"[UnifiedPlayerViewManager] Restored speed: %f for loop (attempt 1)", validSpeed);
                        
                        // Double-check after a bit more time
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            if (self->_player.rate != validSpeed && self->_player.rate > 0) {
                                self->_player.rate = validSpeed;
                                RCTLogInfo(@"[UnifiedPlayerViewManager] Restored speed: %f for loop (attempt 2)", validSpeed);
                            }
                        });
                    }
                });
                RCTLogInfo(@"[UnifiedPlayerViewManager] Looped video - restarted from beginning");
            }
        }];
    } else {
        // If not looping, send completion event
        [self sendEvent:@"onPlaybackComplete" body:@{}];
    }
}

- (void)appDidEnterBackground:(NSNotification *)notification {
    RCTLogInfo(@"[UnifiedPlayerViewManager] App entered background");
    // AVPlayer handles background playback automatically if configured
}

- (void)appDidBecomeActive:(NSNotification *)notification {
    RCTLogInfo(@"[UnifiedPlayerViewManager] App became active");
    // Resume playback if needed
}

#pragma mark - Fullscreen

- (void)toggleFullscreen:(BOOL)fullscreen {
    if (_isFullscreen == fullscreen) {
        return; // Already in the requested state
    }
    
    _isFullscreen = fullscreen;
    
    // Get root view controller
    UIViewController *rootViewController = nil;
    UIWindow *window = nil;
    
    // Get key window - try modern API first (iOS 13+)
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [[UIApplication sharedApplication] connectedScenes];
        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (window) break;
            }
        }
    }
    
    // Fallback: use deprecated keyWindow (iOS 12 and earlier, or if no scene found)
    if (!window) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    
    if (!window) {
        RCTLogError(@"[UnifiedPlayerViewManager] Could not find window for fullscreen");
        if (self.onFullscreenChanged) {
            self.onFullscreenChanged(@{@"isFullscreen": @(NO)});
        }
        _isFullscreen = NO;
        return;
    }
    
    rootViewController = window.rootViewController;
    
    // Navigate to the topmost view controller
    while (rootViewController.presentedViewController) {
        rootViewController = rootViewController.presentedViewController;
    }
    
    if (!rootViewController) {
        RCTLogError(@"[UnifiedPlayerViewManager] Could not find root view controller for fullscreen");
        if (self.onFullscreenChanged) {
            self.onFullscreenChanged(@{@"isFullscreen": @(NO)});
        }
        _isFullscreen = NO;
        return;
    }
    
    if (fullscreen) {
        // Enter fullscreen
        [self enterFullscreenWithViewController:rootViewController];
    } else {
        // Exit fullscreen
        [self exitFullscreen];
    }
}

- (void)enterFullscreenWithViewController:(UIViewController *)rootViewController {
    // Save original frame and superview
    _originalFrame = self.frame;
    _originalSuperview = self.superview;
    if (_originalSuperview) {
        _originalIndex = [_originalSuperview.subviews indexOfObject:self];
    } else {
        _originalIndex = NSNotFound;
    }

    // Create fullscreen container view controller
    _fullscreenViewController = [[UIViewController alloc] init];
    _fullscreenViewController.view.backgroundColor = [UIColor blackColor];
    _fullscreenViewController.modalPresentationStyle = UIModalPresentationFullScreen;

    // Create container view for the player
    _fullscreenContainer = [[UIView alloc] initWithFrame:rootViewController.view.bounds];
    _fullscreenContainer.backgroundColor = [UIColor blackColor];
    [_fullscreenViewController.view addSubview:_fullscreenContainer];

    // Move player to fullscreen container
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    self.frame = screenBounds;
    [_fullscreenContainer addSubview:self];

    // Update player layer frame
    _playerLayer.frame = screenBounds;

    // Create close button
    _fullscreenCloseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _fullscreenCloseButton.translatesAutoresizingMaskIntoConstraints = NO;

    // Create X icon using SF Symbols (iOS 13+) or fallback to text
    if (@available(iOS 13.0, *)) {
        UIImage *closeImage = [UIImage systemImageNamed:@"xmark.circle.fill"];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightMedium];
        closeImage = [closeImage imageByApplyingSymbolConfiguration:config];
        [_fullscreenCloseButton setImage:closeImage forState:UIControlStateNormal];
        _fullscreenCloseButton.tintColor = [UIColor whiteColor];
    } else {
        // Fallback for iOS 12
        [_fullscreenCloseButton setTitle:@"✕" forState:UIControlStateNormal];
        _fullscreenCloseButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
        [_fullscreenCloseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }

    // Style the button with semi-transparent background
    _fullscreenCloseButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    _fullscreenCloseButton.layer.cornerRadius = 22;
    _fullscreenCloseButton.clipsToBounds = YES;

    // Add action
    [_fullscreenCloseButton addTarget:self action:@selector(closeButtonTapped) forControlEvents:UIControlEventTouchUpInside];

    // Add to fullscreen container
    [_fullscreenContainer addSubview:_fullscreenCloseButton];

    // Position in top-right corner with safe area
    [NSLayoutConstraint activateConstraints:@[
        [_fullscreenCloseButton.widthAnchor constraintEqualToConstant:44],
        [_fullscreenCloseButton.heightAnchor constraintEqualToConstant:44],
        [_fullscreenCloseButton.topAnchor constraintEqualToAnchor:_fullscreenContainer.safeAreaLayoutGuide.topAnchor constant:16],
        [_fullscreenCloseButton.trailingAnchor constraintEqualToAnchor:_fullscreenContainer.safeAreaLayoutGuide.trailingAnchor constant:-16]
    ]];

    // Configure orientation
    NSNumber *orientationValue = [NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight];
    [[UIDevice currentDevice] setValue:orientationValue forKey:@"orientation"];

    // Present fullscreen view controller
    [rootViewController presentViewController:_fullscreenViewController animated:YES completion:^{
        // Force landscape orientation
        [UIViewController attemptRotationToDeviceOrientation];

        // Send event
        if (self.onFullscreenChanged) {
            self.onFullscreenChanged(@{@"isFullscreen": @(YES)});
        }
    }];
}

- (void)closeButtonTapped {
    [self exitFullscreen];
}

- (void)exitFullscreen {
    // Restore portrait orientation first
    NSNumber *orientationValue = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
    [[UIDevice currentDevice] setValue:orientationValue forKey:@"orientation"];
    
    // Dismiss fullscreen view controller if we have a reference to it
    if (_fullscreenViewController && _fullscreenViewController.presentingViewController) {
        [_fullscreenViewController dismissViewControllerAnimated:YES completion:^{
            // Restore player to original position
            [self restorePlayerFromFullscreen];
            
            // Force portrait orientation
            [UIViewController attemptRotationToDeviceOrientation];
            
            // Send event
            if (self.onFullscreenChanged) {
                self.onFullscreenChanged(@{@"isFullscreen": @(NO)});
            }
        }];
    } else {
        // Fallback: try to find and dismiss any presented view controller
        UIWindow *window = nil;
        
        // Get key window - try modern API first (iOS 13+)
        if (@available(iOS 13.0, *)) {
            NSSet<UIScene *> *connectedScenes = [[UIApplication sharedApplication] connectedScenes];
            for (UIScene *scene in connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            window = w;
                            break;
                        }
                    }
                    if (window) break;
                }
            }
        }
        
        // Fallback: use deprecated keyWindow (iOS 12 and earlier, or if no scene found)
        if (!window) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            window = [[UIApplication sharedApplication] keyWindow];
            #pragma clang diagnostic pop
        }
        
        if (window) {
            UIViewController *rootVC = window.rootViewController;
            while (rootVC.presentedViewController) {
                rootVC = rootVC.presentedViewController;
            }
            
            if (rootVC.presentingViewController) {
                [rootVC dismissViewControllerAnimated:YES completion:^{
                    [self restorePlayerFromFullscreen];
                    [UIViewController attemptRotationToDeviceOrientation];
                    if (self.onFullscreenChanged) {
                        self.onFullscreenChanged(@{@"isFullscreen": @(NO)});
                    }
                }];
                return;
            }
        }
        
        // Last resort: just restore player position
        [self restorePlayerFromFullscreen];
        [UIViewController attemptRotationToDeviceOrientation];
        if (self.onFullscreenChanged) {
            self.onFullscreenChanged(@{@"isFullscreen": @(NO)});
        }
    }
}

- (void)restorePlayerFromFullscreen {
    if (_originalSuperview && _originalIndex != NSNotFound) {
        // Restore original frame
        self.frame = _originalFrame;

        // Move back to original superview
        [self removeFromSuperview];

        // Insert at original index
        if (_originalIndex < _originalSuperview.subviews.count) {
            [_originalSuperview insertSubview:self atIndex:_originalIndex];
        } else {
            [_originalSuperview addSubview:self];
        }

        // Update player layer frame
        _playerLayer.frame = self.bounds;

        // Clean up
        _originalSuperview = nil;
        _fullscreenContainer = nil;
        _fullscreenViewController = nil;
        _fullscreenCloseButton = nil;
    }
}

#pragma mark - Recording (Placeholder - can be implemented later)

- (void)captureFrameWithCompletion:(void (^)(NSString * _Nullable base64String, NSError * _Nullable error))completion {
    if (!completion) {
        return;
    }
    
    if (!_playerItem || _playerItem.status != AVPlayerItemStatusReadyToPlay) {
        completion(nil, [NSError errorWithDomain:@"UnifiedPlayer" 
                                             code:1 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Player item not ready"}]);
        return;
    }
    
    if (!_playerLayer) {
        completion(nil, [NSError errorWithDomain:@"UnifiedPlayer" 
                                             code:2 
                                         userInfo:@{NSLocalizedDescriptionKey: @"Player layer not available"}]);
        return;
    }
    
    // Use AVAssetImageGenerator to capture the current frame
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:_playerItem.asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    
    CMTime currentTime = _player.currentTime;
    if (!CMTIME_IS_VALID(currentTime)) {
        currentTime = kCMTimeZero;
    }
    
    // Generate the image
    [imageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:currentTime]]
                                          completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
                if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
            return;
        }
        
        if (result != AVAssetImageGeneratorSucceeded || !image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UnifiedPlayer" 
                                                     code:3 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate image"}]);
            });
            return;
        }
        
        // Convert CGImage to UIImage
        UIImage *uiImage = [UIImage imageWithCGImage:image];
        
        // Convert to JPEG data
        NSData *imageData = UIImageJPEGRepresentation(uiImage, 0.8);
        if (!imageData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError errorWithDomain:@"UnifiedPlayer" 
                                                     code:4 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert image to JPEG"}]);
            });
            return;
        }
        
        // Encode to base64
        NSString *base64String = [imageData base64EncodedStringWithOptions:0];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(base64String, nil);
        });
    }];
}

- (void)captureFrameForRecording {
    // Placeholder
}

- (BOOL)startRecordingToPath:(NSString *)outputPath {
    // Placeholder
    return NO;
}

- (void)startFrameCapture {
    // Placeholder
}

- (NSString *)stopRecording {
    // Placeholder
    return @"";
}

@end

#pragma mark - View Manager

@interface UnifiedPlayerViewManager : RCTViewManager
@end

@implementation UnifiedPlayerViewManager

RCT_EXPORT_MODULE(UnifiedPlayerView)

- (UIView *)view {
    return [[UnifiedPlayerUIView alloc] init];
}

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

RCT_CUSTOM_VIEW_PROPERTY(thumbnailUrl, NSString, UnifiedPlayerUIView)
{
    view.thumbnailUrlString = json;
    [view setupThumbnailWithUrlString:json];
}

RCT_CUSTOM_VIEW_PROPERTY(autoplay, BOOL, UnifiedPlayerUIView)
{
    view.autoplay = [RCTConvert BOOL:json];
}

RCT_CUSTOM_VIEW_PROPERTY(loop, BOOL, UnifiedPlayerUIView)
{
    BOOL loopValue = [RCTConvert BOOL:json];
    [view setLoop:loopValue];
}

RCT_CUSTOM_VIEW_PROPERTY(mediaOptions, NSArray, UnifiedPlayerUIView)
{
    view.mediaOptions = [RCTConvert NSArray:json];
}

RCT_CUSTOM_VIEW_PROPERTY(isPaused, BOOL, UnifiedPlayerUIView)
{
    view.isPaused = [RCTConvert BOOL:json];
    if ([RCTConvert BOOL:json]) {
        [view pause];
    } else {
        [view play];
    }
}

RCT_CUSTOM_VIEW_PROPERTY(isFullscreen, BOOL, UnifiedPlayerUIView)
{
    [view toggleFullscreen:[RCTConvert BOOL:json]];
}

RCT_EXPORT_VIEW_PROPERTY(onLoadStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onReadyToPlay, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onProgress, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPlaybackComplete, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPlaybackStalled, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPlaybackResumed, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPlaying, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onPaused, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onFullscreenChanged, RCTDirectEventBlock)

@end
