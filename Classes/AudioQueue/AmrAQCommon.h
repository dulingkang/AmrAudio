//
//  AmrAQCommon.h
//  SpeakHereAmr
//
//  Created by Yu Guangzhen on 13-7-14.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef SpeakHereAmr_AmrAQCommon_h
#define SpeakHereAmr_AmrAQCommon_h

// 音频队列缓冲数，和单个缓冲数据的时间
#define kNumberRecordBuffers        3
#define kBufferDurationSeconds      1

typedef enum {
    AmrAudioStateRunning,
    AmrAudioStateStopped,
    AmrAudioStateError,
} AmrAudioState;


#endif
