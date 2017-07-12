//
//  AQLevelMeterReporter.h
//  SpeakHereAmr
//
//  语音波形收集 定时（kRefreshHz）发出level notification
//
//  Created by YuGuangzhen on 13-7-17.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>
#include <iostream>

class MeterTable;

#define kLevelFalloffPerSec .8
#define kMinDBvalue         -80.0
#define kRefreshHz          1. / 30.;

#define kLevelValue         @"leveValue"        // 音量大小
#define kChannelIndex       @"channelIndex"     // 所属声道
#define kNotifyLevelMeter   @"notifyLevelMeter" // default key

// A LevelMeter subclass which is used specifically for AudioQueue objects
@interface AQLevelMeterReporter : NSObject {
	AudioQueueRef				_aq;                // The AudioQueue object
	AudioQueueLevelMeterState	*_chan_lvls;
	NSArray						*_channelNumbers;// Array of NSNumber objects: The indices of the channels to display in this meter
	NSArray						*_subLevelMeters;
	MeterTable					*_meterTable;
	NSTimer						*_updateTimer;
	CGFloat						_refreshHz;     // How many times per second to redraw
	CFAbsoluteTime				_peakFalloffLastFire;
    
    NSString                    *_notifyKey;
}

/* 设置aq后，AQLevelMeterReporter自动收集语音波形，并发送语音波形通知，通知字典结构
 @param aq          要收集语音波形的语音队列对象
 @param notifyKey   通知的KEY，默认为kNotifyLevelMeter
 
 @通知数据存储在 (NSNotification userInfo) 中
 结构为: 
 NSDictionary {
    kLevelValue   : value        // 音量大小
    kChannelIndex : value        // 所属声道
 }
*/
- (void)setAq:(AudioQueueRef)aq withNotifyKey:(NSString *)notifyKey;

@end
