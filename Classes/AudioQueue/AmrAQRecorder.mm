//
//  AQRecorder.cpp
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#include "AmrAQRecorder.h"
#include "AmrEncodeSession.h"
#include "MeterTable.h"

/* fix time bug lastNotFullSize. AudioQueue貌似会同时写两个buffer，人品不好的时候会出现下面的状况，计数比实际录音时间延迟一秒
 IsRunningCallback      [line 152] 1374141331: Voice recorder is running callback, old status: 1 new status: 1
 InputBufferCallback    [line 122] 1374141333: mAudioDataByteSize: 16000 // 1.延迟一秒，距离开始用了两秒才给回调～
 Encode                 [line 022] 1374141333: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141334: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141334: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141335: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141335: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141336: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141336: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141337: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141337: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141338: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141338: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141339: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141339: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141340: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141340: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141341: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141341: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141342: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141342: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141343: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141343: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141343: mAudioDataByteSize: 12152 // 距离上一次不到一秒
 Encode                 [line 022] 1374141343: Encode pcmByteSize: 12152 // 结束不满一个buffer,也回调了
 InputBufferCallback    [line 122] 1374141344: mAudioDataByteSize: 16000
 Encode                 [line 022] 1374141344: Encode pcmByteSize: 16000
 InputBufferCallback    [line 122] 1374141345: mAudioDataByteSize: 8576 // 2.两个不满的buffer，造成总时长少一秒
 Encode                 [line 022] 1374141345: Encode pcmByteSize: 8576
 InputBufferCallback    [line 122] 1374141345: mAudioDataByteSize: 0
 InputBufferCallback    [line 122] 1374141345: mAudioDataByteSize: 0
 IsRunningCallback      [line 152] 1374141345: Voice recorder is running callback, old status: 0 new status: 0
 */
static int lastNotFullSize = 0;

AmrAQRecorder::AmrAQRecorder() : mQueue(NULL),
                                 mIsRunning(false),
                                 mIsInitialized(false),
//                                 mChannelLevels(NULL),
//                                 mMeterTable(NULL),
                                 mEncodeSession(NULL),
                                 mListener(NULL) {
//    InitLevelMeter();
}

AmrAQRecorder::~AmrAQRecorder() {
    if (mQueue) {
        AudioQueueDispose(mQueue, true);
        mQueue = NULL;
    }
    if (mEncodeSession) {
        delete mEncodeSession;
        mEncodeSession = NULL;
    }
    mListener = NULL;
//    if (mChannelLevels) {
//        free(mChannelLevels);
//        mChannelLevels = NULL;
//    }
//    if (mMeterTable) {
//        delete mMeterTable;
//        mMeterTable = NULL;
//    }
}

#pragma mark - init recorder
void AmrAQRecorder::InitRecorder(AmrCodecType codecType, int mode) {
    if (mIsInitialized) {
        Stop();
    }
    SetupEncodeSession(codecType, mode);
    SetupNewQueue(codecType);
    mIsInitialized = true;
}

void AmrAQRecorder::SetupEncodeSession(AmrCodecType codecType, int mode) {
    if (mEncodeSession == NULL) {
        mEncodeSession = new AmrEncodeSession(codecType, mode);
    } else {
        if (codecType != mEncodeSession->CodecType() || mode != mEncodeSession->Mode()) {
            // 编码格式不同，重新创建新的解码器
            delete mEncodeSession, mEncodeSession = NULL;
            mEncodeSession = new AmrEncodeSession(codecType, mode);
        }
    }
}

void AmrAQRecorder::SetupNewQueue(AmrCodecType codecType) {
    lastNotFullSize = 0;
    // specify the recording format for amr_nb or amr_wb
    AudioStreamBasicDescription format;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mSampleRate = (codecType == amr_nb) ? AMR_NB_SAMPLING_FREQUENCY : AMR_WB_SAMPLING_FREQUENCY;
    format.mChannelsPerFrame = NUMBER_OF_CHANNELS;
    format.mBitsPerChannel = AMR_SAMPLING_BIT_DEPTH;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = (format.mBitsPerChannel/8) * format.mChannelsPerFrame;
    format.mBytesPerPacket = format.mBytesPerFrame * format.mFramesPerPacket;
    mFormat = format;
    
    // create the queue
    OSStatus status = AudioQueueNewInput(&mFormat,
                                         InputBufferCallback,
                                         this,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &mQueue);
    LOG_IF_ERROR((long)status, "calling audio AudioQueueNewInput, status: %ld", (long)status);
    
    // set level meter enable
    UInt32 val = true;
    AudioQueueSetProperty(mQueue,
                          kAudioQueueProperty_EnableLevelMetering,
                          &val,
                          sizeof(UInt32));

    // set IsRunning callback, not necessary for recorder
    status = AudioQueueAddPropertyListener(mQueue,
                                           kAudioQueueProperty_IsRunning,
                                           IsRunningCallback,
                                           this);
    LOG_IF_ERROR(status, "calling AudioQueueAddPropertyListener, status: %ld", (long)status);

    // allocate and enqueue buffers
    // buffer size, one buffer for one second data
    int oneBufferSize = OneBufferByteSize();
    for (int i = 0; i < kNumberRecordBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, oneBufferSize, &mBuffers[i]);
        LOG_IF_ERROR(status, "calling audio AudioQueueAllocateBuffer, status: %ld", (long)status);
        status = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
        LOG_IF_ERROR(status, "calling audio AudioQueueEnqueueBuffer, status: %ld", (long)status);
    }
}

int AmrAQRecorder::OneBufferByteSize() {
    return mFormat.mSampleRate*(mFormat.mBitsPerChannel/8)*mFormat.mChannelsPerFrame*kBufferDurationSeconds; // amr_nb:16000 amr_wb:32000;
}

#pragma mark - AudioQueue callback
// ____________________________________________________________________________________
// AudioQueue callback function, called when an input buffers has been filled.
void AmrAQRecorder::InputBufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc) {
    AmrAQRecorder *THIS = (AmrAQRecorder *)inUserData;
    LOG_IF_DEBUG("mAudioDataByteSize: %ld", (long)inBuffer->mAudioDataByteSize);
    assert(THIS->mEncodeSession); //
    if (inBuffer->mAudioDataByteSize > 0) {
        const short* orignal_speech = reinterpret_cast<const short*>(inBuffer->mAudioData);
        int predict_amr_size = THIS->mEncodeSession->GetAmrByteSizeByPcmSize(inBuffer->mAudioDataByteSize);
        unsigned char* amr = new unsigned char[predict_amr_size];
        memset(amr, 0, predict_amr_size);  // ANDYYU: Not necessary?
        int num_enc_bytes = THIS->mEncodeSession->Encode(orignal_speech, amr, inBuffer->mAudioDataByteSize);
        if (THIS->Listener()) {
            int fullSize = THIS->OneBufferByteSize();
            bool isFullBuffer = false;
            if (inBuffer->mAudioDataByteSize + lastNotFullSize >= fullSize) {
                isFullBuffer = true;
                lastNotFullSize = inBuffer->mAudioDataByteSize + lastNotFullSize - fullSize;
            } else {
                lastNotFullSize = inBuffer->mAudioDataByteSize + lastNotFullSize;
            }
            THIS->Listener()->InputBufferReceived(amr, num_enc_bytes, isFullBuffer);
        }
        delete[] amr;
    }
    if (THIS->IsRunning()) {
        AudioQueueEnqueueBuffer(THIS->mQueue, inBuffer, 0, NULL);
    }
}

// 录音时不需要监视IsRunning状态
void AmrAQRecorder::IsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    AmrAQRecorder *THIS = (AmrAQRecorder *)inUserData;
    UInt32 size = 0;
    // sizeof(THIS->mIsRunning); iOS6  kAudioQueueProperty_IsRunning属性改成UInt32了，为了兼容先取size
    OSStatus status = AudioQueueGetPropertySize(inAQ, kAudioQueueProperty_IsRunning, &size);
    LOG_IF_ERROR(status, "calling audio AudioQueueGetPropertySize, status: %ld", (long)status);
    if (size > 0) {
        UInt32 isRunning = 0;
        status = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
        if (status == noErr) {
            LOG_IF_DEBUG("Voice recorder is running callback, old status: %d new status: %ld", THIS->mIsRunning, (long)isRunning);
            THIS->mIsRunning = isRunning;
            if (THIS->Listener()) {
                if (THIS->mIsRunning) {
                    LOG_IF_DEBUG("AmrAQRecorder::IsRunningCallback, running");
                    THIS->Listener()->RecordingStateChanged(AmrAudioStateRunning);
                } else {
                    LOG_IF_DEBUG("AmrAQRecorder::IsRunningCallback, stoped");
                    THIS->Listener()->RecordingStateChanged(AmrAudioStateStopped);
                }
            }
        }
    }
}

#pragma mark - start/stop/pause/resume queue
void AmrAQRecorder::Start() {
    if (!mIsInitialized) {
        InitRecorder();
    }
    mIsRunning = true;
    OSStatus status = AudioQueueStart(mQueue, NULL);
    LOG_IF_ERROR(status, "calling audio queue start, status: %ld", (long)status);
}

// 函数名和音频队列的含义有歧义
// 实际上执行Stop时，会执行AudioQueueDispose，把音频队列所有内容清空，真正的结束录制
void AmrAQRecorder::Stop() {
    mIsInitialized = false;
    mIsRunning = false;
    if (mQueue) {
        OSStatus status = AudioQueueStop(mQueue, true);
        LOG_IF_ERROR(status, "calling audio AudioQueueStop, status: %ld", (long)status);
        status = AudioQueueDispose(mQueue, true);
        LOG_IF_ERROR(status, "calling audio AudioQueueDispose, status: %ld", (long)status);
        mQueue = NULL;
    }
    // 相同codecType和mode的amr解码器可复用，不需要删除
//    if (mEncodeSession) {
//        delete mEncodeSession;
//        mEncodeSession = NULL;
//    }
}

void AmrAQRecorder::Pause() {
    // not test
    mIsRunning = false;
    OSStatus status = AudioQueuePause(mQueue);
    LOG_IF_ERROR(status, "calling audio AudioQueuePause, status: %ld", (long)status);
}

void AmrAQRecorder::Resume() {
    // not test
    mIsRunning = true;
    OSStatus status = AudioQueueStart(mQueue, NULL);
    LOG_IF_ERROR(status, "calling audio AudioQueueStart, status: %ld", (long)status);
}

/* ANDYYU: 已统一到AQLevelMeterReporter
#pragma mark - level Meter  录播是一样的，代码冗余，二次设计可以统一下？
void AmrAQRecorder::InitLevelMeter() {
    if (mChannelLevels == NULL) {
        mChannelLevels = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState)*NUMBER_OF_CHANNELS);
    }
    if (mMeterTable == NULL) {
        mMeterTable = new MeterTable(kMinDBvalue);
    }
}

OSErr AmrAQRecorder::GetLevelMeter() {
    UInt32 data_sz = sizeof(AudioQueueLevelMeterState);
    OSErr status = AudioQueueGetProperty(mQueue,
                                        kAudioQueueProperty_CurrentLevelMeterDB,
                                         mChannelLevels,
                                         &data_sz);
    LOG_IF_ERROR(status, "calling audio AudioQueueGetProperty, status: %d", status);
    return status;
}

float AmrAQRecorder::GetChannelLevel(int channel) {
    return mMeterTable->ValueAt((float)(mChannelLevels[channel].mAveragePower));
}

bool AmrAQRecorder::isQueueExsit() {
    return (mQueue == NULL) ? false : true;
}

bool AmrAQRecorder:: isChannelExsit()
{
    return (mChannelLevels == NULL) ? false : true;
}
*/

