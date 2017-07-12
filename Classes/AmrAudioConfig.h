//
//  AmrConfig.h
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef SpeakHereAmr_AmrAudioConfig_h
#define SpeakHereAmr_AmrAudioConfig_h

#include "assert.h"

// ======
// AMRAudio configuration options
// ======

// 录音文件跟目录
#define AMR_RECORD_ROOT_FOLDER [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @"amr_record"]
// @"/User/YuGuangzhen/Desktop/"

// 强制听筒 会写NSUserDefaults standardUserDefaults
#define KFORCERECEIVER @"KForceReceiver"

// 语音波形
#define kLevelFalloffPerSec         .8
#define KLevelMeterRefreshHz        1./30
#define kMinDBvalue                 -80.0

#define AMR_WB_DECODE_SUPPORT       0 // 设置是否支持amr-wb解码
#define AMR_WB_ENCODE_SUPPORT       0 // 设置不可用，opencore-amr不支持amr-wb编码

// ==========================================================================================
// ======
// Debug output configuration options
// ======

// When set to 1 AMR will print debug info
#ifndef AMR_DEBUG
    #define AMR_DEBUG 1
#endif

// When set to 1 AMR will report crash when exception happen
#ifndef AMR_REPORT_EXCEPTION
    #define AMR_REPORT_EXCEPTION 1 || DEBUG
#endif


// Macro function definition
//__PRETTY_FUNCTION__
#if AMR_DEBUG && DEBUG
    #define LOG_IF_DEBUG(fmt, ...) printf((" %-22s [line %03d] %ld: " fmt "\n"), __FUNCTION__, __LINE__, time(0), ##__VA_ARGS__)
    #define LOG_IF_ERROR(error, fmt, ...)                   \
                do {                                        \
                    if (error) {                            \
                        LOG_IF_DEBUG("ERROR: " fmt, ##__VA_ARGS__);   \
                    }                                       \
                } while(0)
#else
    #define LOG_IF_DEBUG(...)
    #define LOG_IF_ERROR(...)
#endif

#if AMR_REPORT_EXCEPTION || DEBUG
    #define ASSERT_IF_DEBUG(x) assert(x)
#else
    #define ASSERT_IF_DEBUG(x)
#endif

#endif
