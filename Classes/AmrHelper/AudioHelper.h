//
//  AudioHelper.h
//  SpeakHereAmr
//
//  全静态方法的类
//  处理AudioSession相关内容，如话筒切换、耳机插拔、
//  TODO: 可以考虑实例化这个类，把挡屏监视放到这处理？
//
//  Created by YuGuangzhen on 13-7-16.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kDidHeadphoneMode @"DidHeadphoneMode"

@interface AudioHelper : NSObject {
    
}

+ (void)initAudioSession;

+ (void)setAudioSessionActive:(BOOL)active;
// config for app settings
+ (void)setForceReceiver:(BOOL)force;
+ (BOOL)isForceReceiver;

// Set AudioSession Property
+ (void)setAudioRouteHeadphone;
+ (void)setAudioRouteSpeaker;

+ (void)setAudioCategroyRecordAndPlay;
+ (void)setAudioCategroyPlayback;
+ (void)setAudioCategroyRecord;

// Status
+ (BOOL)isHeadphonePlugin;
+ (BOOL)isMuted;

// proximityMonitoringEnabled
+ (void)setProximityMonitoring:(BOOL)Enable;

@end

