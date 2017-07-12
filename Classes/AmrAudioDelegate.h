//
//  AmrAudioDelegate.h
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef SpeakHereAmr_AmrRecorderDelegate_h
#define SpeakHereAmr_AmrRecorderDelegate_h

#include "AmrAQCommon.h"

@class AmrPlayer;
@class AmrRecorder;
@protocol AmrPlayerDelegate <NSObject>

@optional
/* 播放状态改变时回调 
 开始和完成播放时通知
*/
- (void)onPlaybackStateChanged:(AmrAudioState)state player:(AmrPlayer *)player;

/* 每播放完成一个缓冲数据调用一次，
 调用间隔: kBufferDurationSeconds (可用于播放计时)
 (播放流时，如果数据断掉，可能不足kBufferDurationSeconds就会调用) 
*/
- (void)onOneBufferPlayed:(AmrPlayer *)player;

/* 每隔KRefreshHz秒报告一次音量
 @param level      level range: 0.0-1.0
 改为通知报告了
*/
//- (void)onPlayLevelMeter:(float)level;

@end

@protocol AmrRecorderDelegate <NSObject>

@optional
/* 播放状态改变时回调 
 开始和结束录音时通知
*/
- (void)onRecordingStateChanged:(AmrAudioState)state recorder:(AmrRecorder *)recorder;

/* 录音数据回调，
 调用间隔: kBufferDurationSeconds (可用于录音计时，但不完全准确。有时没填满一个buffer也会回调,详见AmrRecorder.m)
*/
- (void)onInputBufferReceived:(NSData *)data isFullBuffer:(BOOL)isFull recorder:(AmrRecorder *)recorder;

/* 每隔KRefreshHz秒报告一次音量
 @param level    range: 0.0-1.0
 改为通知报告了
*/
//- (void)onRecordLevelMeter:(float)level;

@end

#endif
