//
//  AQPlayer.h
//  SpeakHereAmr
//
//  对(Audio Queue)+(amr Decode)的封装 实现播放 C++ Class
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#ifndef __SpeakHereAmr__AmrAQPlayer__
#define __SpeakHereAmr__AmrAQPlayer__

#include <AudioToolbox/AudioToolbox.h>
#include <iostream>
#include <deque>
#include <string>
#include "AmrAQCommon.h"
#include "AmrCodecType.h"

class MeterTable;
class AmrDecodeSession;
class IAmrAQPlayerListener {
public:
    virtual void PlaybackStateChanged(AmrAudioState state) = 0;
    virtual void OneBufferPlayed() = 0;
};

/* class AmrAQPlayer
 音频队列实现播放，不涉及AudioSession相关的内容（切换听筒，初始化AudioSession等）。
 */
class AmrAQPlayer {
public:
    AmrAQPlayer();
    ~AmrAQPlayer();
    /* InitPlayer init audioqueue and decodesession
     only can be called before Start() and after Stop()
    */
    void InitPlayer(AmrCodecType codecType = amr_nb, int mode = AMRNB_MR74);
    void SetListener(IAmrAQPlayerListener *listener)    { mListener = listener; };
    IAmrAQPlayerListener * Listener()                   { return mListener; };

    void WriteBuffer(const unsigned char* amr, int len);
    bool StartQueue();
    void StopQueue();
    void PauseQueue();
    void ResumeQueue();
    void DisposeQueue();
    // 当前的AudioQueue状态
    Boolean IsRunning() const                           { return (mIsRunning) ? true : false; };
    Boolean IsUserRunning() const                       { return mIsUserRunning; };
    AudioQueueRef Queue() const                         { return mQueue; };
//    OSErr GetLevelMeter();
//    float GetChannelLevel(int channel);
//    bool isQueueExsit();
//    bool isChannelExsit();
    // for AudioSession Interruption States
    bool playbackWasInterrupted() const                 { return mPlaybackWasInterrupted; };
    void setPlaybackWasInterrupted(bool interrupte)     { mPlaybackWasInterrupted = interrupte; };

    int getPlaySeconds(int dataLength);
    int getPlayDataOffset(int offsetSeconds);
    
private: // init
//    void InitLevelMeter();
    void SetupDecodeSession(AmrCodecType codecType = amr_nb, int mode = AMRNB_MR74);
    void SetupNewQueue(AmrCodecType codecType = amr_nb);
    
    void DecodeDataToQueue();
    void cleanUpAudioQueue();

private: // AudioQueue
    AudioQueueRef                       mQueue;
    AudioStreamBasicDescription         mFormat;
    AudioQueueBufferRef                 mBuffers[kNumberRecordBuffers];
    std::deque<AudioQueueBufferRef>     mAvailableBufferQueue;
    std::string                         mAmrBuffer;
    UInt32                              mIsRunning;
    Boolean                             mIsInitialized;
    Boolean                             mIsUserRunning;
    Boolean                             mPlaybackWasInterrupted;
//    AudioQueueLevelMeterState           *mChannelLevels;
//    MeterTable                          *mMeterTable;
    AmrDecodeSession                    *mDecodeSession;
    IAmrAQPlayerListener                 *mListener;
    static void OutputBufferCallback(void* inUserData,
                                 AudioQueueRef inAQ,
                                 AudioQueueBufferRef inCompleteAQBuffer);
    static void IsRunningCallback(void *                    inUserData,
                                  AudioQueueRef             inAQ,
                                  AudioQueuePropertyID      inID);
};
#endif /* defined(__SpeakHereAmr__AQPlayer__) */
