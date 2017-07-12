//
//  AMRType.h
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-12.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

// about amr codec rfc3267 http://www.rfc-editor.org/rfc/rfc3267.txt

#ifndef SpeakHereAmr_AMRCodecDefine_h
#define SpeakHereAmr_AMRCodecDefine_h

#include "AmrAudioConfig.h"

/* @---------------------------------------------------------------------------
 以下宏定义值来自有关amr的rfc4867文档
 http://www.rfc-editor.org/rfc/rfc4867.txt
*/
// 不同编码格式amr文件头的magic number
#define AMR_NB_MAGIC_NUMBER "#!AMR\n"
#define AMR_WB_MAGIC_NUMBER "#!AMR-WB\n"
#define AMR_NB_MULTI_CHANNEL_MAGIC_NUMBER "#!AMR_MC1.0\n"
#define AMR_WB_MULTI_CHANNEL_MAGIC_NUMBER "#!AMR-WB_MC1.0\n"
// 每秒50帧
#define AMR_FRAME_COUNT_PER_SECOND 50
// 每帧0.02s（20ms）
#define AMR_PERFORMED_SECOND_PER_FRAME 0.02 // (1 / AMR_FRAME_COUNT_PER_SECOND)

/* AMR规定的采样结构，PCM(Pulse-code modulation 脉冲编码调制)结构
 http://en.wikipedia.org/wiki/Audio_bit_depth
 Bit rate = (sampling rate) × (bit depth) × (number of channels)
 比特率 = 采样频率 × 采样位数 × 声道数
 @amr-nb    (sampling rate) = 8kHz
 @amr-wb    (sampling rate) = 16kHz
 @amr       (bit depth) = 16bit // rfc4867没有明确指定,但是opencore-amr仅支持16bit-depth
*/
#define AMR_NB_SAMPLING_FREQUENCY 8000.0
#define AMR_WB_SAMPLING_FREQUENCY 16000.0
#define AMR_SAMPLING_BIT_DEPTH 16

// 每个amr帧代表的采样数
#define AMR_NB_SAMPLE_COUNT_PER_FRAME 160   // (AMR_NB_SAMPLING_FREQUENCY * AMR_PERFORMED_SECOND_PER_FRAME)
#define AMR_WB_SAMPLE_COUNT_PER_FRAME 320   // (AMR_WB_SAMPLING_FREQUENCY * AMR_PERFORMED_SECOND_PER_FRAME)
// ----------------------------------------------------------------------------@

/* 声道数
 AMR编解码器(amr codec)本身不支持多声道，但是可以对独立的声道分别进行独立的编解码。
 使用类似下面交叉结构的帧块进行传输和存储
 +----+----+----+----+----+----+
 | 1L | 1R | 2L | 2R | 3L | 3R |
 +----+----+----+----+----+----+
 |<------->|<------->|<------->|
   Frame-    Frame-    Frame-
   Block 1   Block 2   Block 3
*/
#define NUMBER_OF_CHANNELS 1

// 每个amr采样的字节长度（采样位数/8）
#define AMR_BYTES_PER_SAMPLE 2  // (AMR_SAMPLING_BIT_DEPTH / 8)

// 每个amr帧对应的原始采样数据字节长度（一个采样的字节长度*一帧代表的采样数）
#define AMR_NB_SAMPLE_BYTES_PER_FRAME 320   // (AMR_BYTES_PER_SAMPLE * AMR_NB_SAMPLE_COUNT_PER_FRAME) 
#define AMR_WB_SAMPLE_BYTES_PER_FRAME 640   // (AMR_BYTES_PER_SAMPLE * AMR_WB_SAMPLE_COUNT_PER_FRAME) 

// 每帧amrnb数据占用的最大存储空间bytes
//#define AMR_NB_MAX_FRAME_SIZE 32
//#define AMR_WB_MAX_FRAME_SIZE 62

#endif
