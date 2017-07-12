//
//  AQRecorder.h
//  SpeakHereAmr
//
//  对(Audio Queue)＋(amr Encode)的封装 实现录音 C++ Class
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef __SpeakHereAmr__AmrAQRecorder__
#define __SpeakHereAmr__AmrAQRecorder__

#include <AudioToolbox/AudioToolbox.h>
#include "AmrCodecType.h"
#include "AmrAQCommon.h"
#include <iostream>

//class AQLevelMeterReporter;
class AmrEncodeSession;
class IAmrAQRecorderListener {
public:
    virtual void RecordingStateChanged(AmrAudioState state) = 0;
    virtual void InputBufferReceived(const unsigned char* amr, int byteSize, bool isFullBuffer) = 0;
};

/* class AmrAQRecorder
 音频队列实现录音，不涉及AudioSession相关的内容（切换听筒，初始化AudioSession等）。
 录音数据通过Listener OnInputBuffer传回
*/
class AmrAQRecorder {
public:
    AmrAQRecorder();
    ~AmrAQRecorder();
    /* InitRecorder     init audioqueue and encodesession
    */
    void InitRecorder(AmrCodecType codecType = amr_nb, int mode = AMRNB_MR74); // 仅支持amrnb编码
    void SetListener(IAmrAQRecorderListener *listener)  { mListener = listener; };
    IAmrAQRecorderListener * Listener()                 { return mListener; };

    void Start(); // 非主线程不能播放
    void Stop();
    void Pause();
    void Resume();
    Boolean IsRunning() const                           { return mIsRunning; };
    AudioQueueRef Queue() const                         { return mQueue; };
//    OSErr GetLevelMeter();
//    float GetChannelLevel(int channel);
//    bool isQueueExsit();
//    bool isChannelExsit();
    
private: // init
//    void InitLevelMeter();
    void SetupEncodeSession(AmrCodecType codecType = amr_nb, int mode = AMRNB_MR74);
    void SetupNewQueue(AmrCodecType codecType = amr_nb);
    
private:
    int OneBufferByteSize();
    
private: // AudioQueue
    AudioQueueRef                   mQueue;
    AudioStreamBasicDescription     mFormat;
    AudioQueueBufferRef             mBuffers[kNumberRecordBuffers];
    Boolean                         mIsRunning; // 用户的录播状态
    Boolean                         mIsInitialized;
//    AudioQueueLevelMeterState       *mChannelLevels;
//    MeterTable                      *mMeterTable;
    AmrEncodeSession                *mEncodeSession;
    IAmrAQRecorderListener          *mListener;
    static void InputBufferCallback(void *                               inUserData,
                                    AudioQueueRef                        inAQ,
                                    AudioQueueBufferRef                  inBuffer,
                                    const AudioTimeStamp *               inStartTime,
                                    UInt32                               inNumPackets,
                                    const AudioStreamPacketDescription *  inPacketDesc);
    static void IsRunningCallback(void *                    inUserData,
                                  AudioQueueRef             inAQ,
                                  AudioQueuePropertyID      inID);
};

#endif /* defined(__SpeakHereAmr__AQRecorder__) */
