//
//  AmrPlayer.h
//  SpeakHereAmr
//
//  对AmrAQPlayer的封装＋挡屏监测   单例
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import <Foundation/Foundation.h>

//#import "SynthesizeSingleton.h"
#import "AmrAudioDelegate.h"
#import "AmrCodecType.h"

@interface AmrPlayer : NSObject

@property (nonatomic, assign) id<AmrPlayerDelegate> delegate;

@property (nonatomic, readonly) NSTimeInterval currentPlaySeconds;
@property (nonatomic, readonly) NSInteger currentFrameCount;

//SYNTHESIZE_SINGLETON_FOR_CLASS_HEADER(AmrPlayer);

+ (AmrPlayer *)sharedAmrPlayer;

/* 设置播放器格式
 播放前设置，不设置，则使用默认设置amr_nb, AMRNB_MR74
 调用这个函数时，会停止当前正在播放的内容
*/
- (void)setPlayerCodecType:(AmrCodecType)codecType Mode:(int)mode;

/* 播放amr文件
 @param fileName    amr音频文件名（绝对路径）
                    音频文件会一次性读到内存，应避免播放过长的音频
                    TODO: 实现大文件边读边播（通过AppendData和播放回调OnOneBufferPlayed实现）
 @return            文件播放时长second
 */
- (int)playFile:(NSString *)fileName;

- (int)playFile:(NSString *)fileName interval:(NSTimeInterval)interval;

/* 播放amr数据流
 可重复调用
 */
- (void)appendData:(NSData *)data;

/* 停止当前播放
 */
- (void)stop;

- (void)pause;

- (void)resume;

/* 取正在播放的文件全路径
 正在播放时，返回播放文件的全路径
 播放停止时，返回nil
 */
- (NSString *)currentPlayFileName;

/* 计算文件播放长度
 */
- (int)getPlaySecondsOfFile:(NSString *)fileName amrnbMode:(AmrnbMode)amrnbMode;

/* 计算文件播放长度 窄带
 */
- (int)getPlaySecondsOfFileSize:(long long )dataLength amrnbMode:(AmrnbMode)amrnbMode;

/* 启动语音波形(默认不开启)
 @param notifyKey   通知的KEY，默认值为kNotifyLevelMeter
 
 @波形数据存储在 (NSNotification userInfo) 中
 结构为:
 NSDictionary {
     kLevelValue   : value        // 音量大小
     kChannelIndex : value        // 所属声道
 }
 */
- (void)openLevelMeterWithNotifyKey:(NSString *)notifyKey;

- (BOOL)isRunning;

// just for AudioSession
- (BOOL)playbackWasInterrupted;
- (void)setPlaybackWasInterrupted:(BOOL)interrupt;
- (void)startQueue;
- (void)stopQueue;

@end
