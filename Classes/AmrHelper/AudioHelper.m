//
//  AudioHelper.m
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-16.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import "AudioHelper.h"
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MPMusicPlayerController.h>
#import "AmrAudioConfig.h"
#import "AmrPlayer.h"
#import "AmrRecorder.h"
#import <AVFoundation/AVFoundation.h>

//static dispatch_queue_t _audio_WorkingQueue = NULL;

@interface AudioHelper(AmrRecorderAndAmrPlayer)

+ (AmrPlayer *)player;
+ (AmrRecorder *)recorder;
+ (BOOL)isPlaying;
+ (BOOL)isRecording;

@end

@implementation AudioHelper

#pragma mark - AudioSession init/active

+ (void)initAudioSession
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        CFAbsoluteTime startime = CFAbsoluteTimeGetCurrent();
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:audioSession];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionRouteChange:) name:AVAudioSessionRouteChangeNotification object:audioSession];
        
        // [self setAudioSessionActive:YES];
        
        CFAbsoluteTime endtime = CFAbsoluteTimeGetCurrent();
        NSString * tookSecond = [NSString stringWithFormat:@"took %2.5f second",endtime - startime];
        LOG_IF_DEBUG("audiosession init complate! %s ",[tookSecond UTF8String]);
    });
}

+ (void)setAudioSessionActive:(BOOL)active
{
    [[AVAudioSession sharedInstance] setActive:active error:nil];
}

#pragma mark - configure settings
+ (void)setForceReceiver:(BOOL)force
{
    [[NSUserDefaults standardUserDefaults] setBool:force forKey:KFORCERECEIVER];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (force) {
        [self setAudioRouteHeadphone];
    } else {
        [self setAudioRouteSpeaker];
    }
}

+ (BOOL)isForceReceiver
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:KFORCERECEIVER];
}

#pragma mark - AudioSession notifications

+ (void)handleAudioSessionInterruption:(NSNotification *)notification
{
    AVAudioSessionInterruptionType interruptionType = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType) {
        LOG_IF_DEBUG("kAudioSessionBeginInterruption");
		if ([[self recorder] isRunning]) {
			[[self recorder] stop];
		}
		if ([[self player] isRunning]) {
			// the queue will stop itself on an interruption, we just need to update the UI
            if ([[self player] delegate] && [[[self player] delegate] respondsToSelector:@selector(OnPlaybackStateChanged:)]) {
                [[[self player] delegate] onPlaybackStateChanged:AmrAudioStateStopped player:[self player]];
            }
            [[self player] setPlaybackWasInterrupted:YES];
		}
    } else if (AVAudioSessionInterruptionTypeEnded == interruptionType) {
        LOG_IF_DEBUG("kAudioSessionEndInterruption");
        if ([[self player] playbackWasInterrupted]) {
            // we were playing back when we were interrupted, so reset and resume now
            [[self player] startQueue];
            [[self player] setPlaybackWasInterrupted:NO];
        }
    }
}

+ (void)handleAudioSessionRouteChange:(NSNotification *)notification
{
    NSString* seccReason = @"";
    NSInteger reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
//    AVAudioSessionRouteDescription* prevRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory: {
            seccReason = @"The route changed because no suitable route is now available for the specified category.";
        }
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep: {
            seccReason = @"The route changed when the device woke up from sleep.";
        }
            break;
        case AVAudioSessionRouteChangeReasonOverride: {
            seccReason = @"The output route was overridden by the app.";
        }
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange: {
            seccReason = @"The category of the session object changed.";
        }
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
            seccReason = @"The previous audio output path is no longer available.";
            LOG_IF_DEBUG("kAudioSessionRouteChangeReason_OldDeviceUnavailable");
            //[AudioHelper setAudioRouteSpeaker];
        }
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
            seccReason = @"A preferred new audio output path is now available.";
            LOG_IF_DEBUG("kAudioSessionRouteChangeReason_NewDeviceAvailable");
            [AudioHelper setAudioRouteHeadphone];
        }
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default: {
            seccReason = @"The reason for the change is unknown.";
            // stop the queue if we had a non-policy route change
			if ([[AudioHelper recorder] isRunning]) {
				[[AudioHelper recorder] stop];
			}
        }
            break;
    }
    LOG_IF_DEBUG("handleAudioSessionRouteChange reason = %ld, seccReason = %s", (long)reason, [seccReason UTF8String]);
//    AVAudioSession *session = [AVAudioSession sharedInstance];
//    AVAudioSessionPortDescription *input = [[session.currentRoute.inputs count]?session.currentRoute.inputs:nil objectAtIndex:0];
//    if (input.portType == AVAudioSessionPortHeadsetMic) {
//        
//    }
//    if (!session.inputAvailable) {
//        
//    }
}

#pragma mark - AudioSession Settings

+ (void)setAudioRouteHeadphone
{
    [self setAudioCategroyRecordAndPlay];
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidHeadphoneMode object:nil userInfo:@{ kDidHeadphoneMode:@(YES) }];
}

+ (void)setAudioRouteSpeaker
{
    [self setAudioCategroyPlayback];
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidHeadphoneMode object:nil userInfo:@{ kDidHeadphoneMode:@(NO) }];
}

+ (void)setAudioCategroyRecordAndPlay
{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
}

+ (void)setAudioCategroyPlayback
{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
}

+ (void)setAudioCategroyRecord
{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
}

#pragma mark - AudioSession Status

// 是否插入耳机
+ (BOOL)isHeadphonePlugin
{
#if TARGET_IPHONE_SIMULATOR
    // warning *** Simulator mode: audio session code works only on a device
    return NO;
#else
    BOOL ret = NO;
    UInt32 propertySize = sizeof(CFStringRef);
    CFStringRef state = nil;
    // ANDYYU: TODO: ?kAudioSessionProperty_AudioRoute Deprecated in iOS 5.0; Use kAudioSessionProperty_AudioRouteDescription
    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize,&state); // 为什么会泄漏？
    if (state) {
        NSString *s = (NSString *)state;
        LOG_IF_DEBUG("AudioRoute state: %s", [s UTF8String]);
        NSRange r = [s rangeOfString:@"Headphone"];
        if (r.length > 0 || [s isEqualToString:@"Headset"]) {
            ret = YES;
        }
        CFRelease(state);
    }
    return ret;
#endif
}

+ (BOOL)isMuted
{
#if TARGET_IPHONE_SIMULATOR
    // warning *** Simulator mode: audio session code works only on a device
    return NO;
#else
    BOOL ret = NO;
    CFStringRef route = nil;
    UInt32 routeSize = sizeof(CFStringRef);
    OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &routeSize, &route);
    if (status == kAudioSessionNoError)
    {
        if (route == NULL || !CFStringGetLength(route))
        {
            ret = YES;
        }
    }
    CFRelease(route);
    return ret;
#endif
}

#pragma mark - setProximityMonitoring

+ (void)setProximityMonitoring:(BOOL)Enable
{
    [UIDevice currentDevice].proximityMonitoringEnabled = Enable;
}

#pragma mark - private methods

+ (AmrRecorder *)recorder
{
    return [AmrRecorder sharedAmrRecorder];
}

+ (AmrPlayer *)player
{
    return [AmrPlayer sharedAmrPlayer];
}

+ (BOOL)isPlaying
{
    return [[self player] isRunning];
}

+ (BOOL)isRecording
{
    return [[self recorder] isRunning];
}

@end
