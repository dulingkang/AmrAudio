//
//  AmrRecorder.h
//  SpeakHereAmr
//
//  对AmrAQRecorder的封装 单例
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import <Foundation/Foundation.h>

//#import "SynthesizeSingleton.h"
#import "AmrAudioDelegate.h"
#import "AmrCodecType.h"

@interface AmrRecorder : NSObject

@property (nonatomic, assign) id<AmrRecorderDelegate> delegate;

//SYNTHESIZE_SINGLETON_FOR_CLASS_HEADER(AmrRecorder);
+ (AmrRecorder *)sharedAmrRecorder;

/* 设置录音格式［除非有特殊需求，一般不应该调用这个方法］
 录音前设置，不设置，则使用默认设置amr_nb, AMRNB_MR74
 调用这个函数时，会结束当前录音
 */
- (void)setRecorderCodecType:(AmrCodecType)codecType Mode:(int)mode;

/* 开始录音
 @param fileName    录音文件名
                    录音文件目录：AMR_RECORD_ROOT_FOLDER
                    为nil时，不会存文件
*/
- (void)startWithRecordFileName:(NSString *)fileName;
- (void)stop;

/* 启动语音波形(默认开启)
 @param notifyKey   通知的KEY，默认值为kNotifyLevelMeter
 
 @波形数据存储在 (NSNotification userInfo) 中
 结构为:
 NSDictionary {
     kLevelValue   : value        // 音量大小
     kChannelIndex : value        // 所属声道
 }
*/
- (void)openLevelMeterWithNotifyKey:(NSString *)notifyKey;

// for AudioSession
- (BOOL)isRunning;

@end
