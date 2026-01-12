#import "UnifiedPlayerModule.h"
#import "UnifiedPlayerUIView.h"
#import <React/RCTLog.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTUIManager.h>
#import <MobileVLCKit/MobileVLCKit.h>

@implementation UnifiedPlayerModule

RCT_EXPORT_MODULE(UnifiedPlayer);

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"onLoadStart",
        @"onReadyToPlay",
        @"onError",
        @"onProgress",
        @"onPlaybackComplete",
        @"onPlaybackStalled",
        @"onPlaybackResumed",
        @"onPlaying",
        @"onPaused"
    ];
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

#pragma mark - Helper Method

/**
 * Helper method to execute operations on the player view.
 * Eliminates repetitive boilerplate across all methods.
 */
- (void)executeWithPlayerView:(nonnull NSNumber *)reactTag
                     resolver:(RCTPromiseResolveBlock)resolve
                     rejecter:(RCTPromiseRejectBlock)reject
                        block:(void (^)(UnifiedPlayerUIView *playerView))block {
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        UIView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[UnifiedPlayerUIView class]]) {
            reject(@"E_INVALID_VIEW", @"Expected UnifiedPlayerUIView", nil);
            return;
        }
        UnifiedPlayerUIView *playerView = (UnifiedPlayerUIView *)view;
        block(playerView);
    }];
}

#pragma mark - Playback Control

RCT_EXPORT_METHOD(play:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        VLCMediaPlayer *player = [playerView valueForKey:@"player"];
        if (player && player.media) {
            [player play];
            resolve(@(YES));
        } else {
            reject(@"E_PLAYER_ERROR", @"Player or media not initialized", nil);
        }
    }];
}

RCT_EXPORT_METHOD(pause:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        VLCMediaPlayer *player = [playerView valueForKey:@"player"];
        if (player) {
            [player pause];
            resolve(@(YES));
        } else {
            reject(@"E_PLAYER_ERROR", @"Player not initialized", nil);
        }
    }];
}

RCT_EXPORT_METHOD(seekTo:(nonnull NSNumber *)reactTag
                  time:(nonnull NSNumber *)time
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        VLCMediaPlayer *player = [playerView valueForKey:@"player"];
        if (player && player.media) {
            float timeValue = [time floatValue];
            float duration = player.media.length.intValue / 1000.0f;
            float position = duration > 0 ? timeValue / duration : 0;
            position = MAX(0, MIN(1, position));
            [player setPosition:position];
            resolve(@(YES));
        } else {
            reject(@"E_PLAYER_ERROR", @"Player or media not initialized", nil);
        }
    }];
}

#pragma mark - Time & Duration

RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        VLCMediaPlayer *player = [playerView valueForKey:@"player"];
        if (player) {
            float currentTime = player.time.intValue / 1000.0f;
            resolve(@(currentTime));
        } else {
            reject(@"E_PLAYER_ERROR", @"Player not initialized", nil);
        }
    }];
}

RCT_EXPORT_METHOD(getDuration:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        float duration = [playerView getDuration];
        resolve(@(duration));
    }];
}

#pragma mark - Capture & Recording

RCT_EXPORT_METHOD(capture:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        [playerView captureFrameWithCompletion:^(NSString * _Nullable base64String, NSError * _Nullable error) {
            if (error) {
                reject(@"E_CAPTURE_FAILED", error.localizedDescription, error);
            } else if (base64String) {
                resolve(base64String);
            } else {
                reject(@"E_CAPTURE_FAILED", @"Unknown capture error", nil);
            }
        }];
    }];
}

RCT_EXPORT_METHOD(startRecording:(nonnull NSNumber *)reactTag
                  outputPath:(NSString *)outputPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        NSString *finalOutputPath = outputPath;
        if (!finalOutputPath || [finalOutputPath isEqualToString:@""]) {
            NSString *documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            NSString *timestamp = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
            finalOutputPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"recording_%@.mp4", timestamp]];
        }

        BOOL success = [playerView startRecordingToPath:finalOutputPath];
        if (success) {
            resolve(@YES);
        } else {
            reject(@"E_RECORDING_FAILED", @"Failed to start recording", nil);
        }
    }];
}

RCT_EXPORT_METHOD(stopRecording:(nonnull NSNumber *)reactTag
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        NSString *filePath = [playerView stopRecording];
        if (filePath && ![filePath isEqualToString:@""]) {
            resolve(filePath);
        } else {
            reject(@"E_RECORDING_FAILED", @"Failed to stop recording or no recording in progress", nil);
        }
    }];
}

#pragma mark - Fullscreen

RCT_EXPORT_METHOD(toggleFullscreen:(nonnull NSNumber *)reactTag
                  isFullscreen:(BOOL)isFullscreen
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    [self executeWithPlayerView:reactTag resolver:resolve rejecter:reject block:^(UnifiedPlayerUIView *playerView) {
        [playerView toggleFullscreen:isFullscreen];
        resolve(@(YES));
    }];
}

@end
