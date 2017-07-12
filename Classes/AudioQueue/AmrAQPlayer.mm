//
//  AQPlayer.cpp
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#include "AmrAQPlayer.h"
#include "AmrDecodeSession.h"
#include "MeterTable.h"

AmrAQPlayer::AmrAQPlayer() : mQueue(NULL),
                             mIsRunning(0),
                             mIsInitialized(false),
                             mIsUserRunning(false),
                             mPlaybackWasInterrupted(false),
//                             mChannelLevels(NULL),
//                             mMeterTable(NULL),
                             mDecodeSession(NULL),
                             mListener(NULL) {
}

AmrAQPlayer::~AmrAQPlayer() {
    cleanUpAudioQueue();
    if (mDecodeSession) {
        delete mDecodeSession;
        mDecodeSession = NULL;
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
    // mAmrBuffer.clear();
}

#pragma mark - init player
void AmrAQPlayer::InitPlayer(AmrCodecType codecType, int mode) {
    if (mIsInitialized) {
        LOG_IF_DEBUG("[wrong] calling InitPlayer, this func just can be called before StartQueue and after StopQueue");
        DisposeQueue();
    }
    SetupDecodeSession(codecType, mode);
    SetupNewQueue(codecType);
    mIsInitialized = true;
}

void AmrAQPlayer::SetupDecodeSession(AmrCodecType codecType, int mode) {
    if (mDecodeSession == NULL) {
        mDecodeSession = new AmrDecodeSession(codecType, mode);
    } else {
        if (codecType != mDecodeSession->CodecType() || mode != mDecodeSession->Mode()) {
            // 编码格式不同，重新创建新的解码器
            delete mDecodeSession, mDecodeSession = NULL;
            mDecodeSession = new AmrDecodeSession(codecType, mode);
        }
    }
}

void AmrAQPlayer::SetupNewQueue(AmrCodecType codecType) {
    LOG_IF_DEBUG(">>>>>>>>>> [AudioQueueNewOutput]");
    // specify the playing format for amr_nb or amr_wb
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
    OSStatus status = AudioQueueNewOutput(&mFormat,
                                         OutputBufferCallback,
                                         this,
                                         CFRunLoopGetCurrent(),
                                         kCFRunLoopCommonModes,
                                         0,
                                         &mQueue);
    LOG_IF_ERROR(status, "calling audio AudioQueueNewInput");
    // set the volume of the queue
    status = AudioQueueSetParameter(mQueue, kAudioQueueParam_Volume, 1.0f);
    LOG_IF_ERROR(status, "calling audio AudioQueueSetParameter, status: %ld", (long)status);
    
    // set level meter enable
    UInt32 val = true;
    AudioQueueSetProperty(mQueue,
                          kAudioQueueProperty_EnableLevelMetering,
                          &val,
                          sizeof(UInt32));
    
    // set IsRunning callback
    status = AudioQueueAddPropertyListener(mQueue, kAudioQueueProperty_IsRunning, IsRunningCallback, this);
    LOG_IF_ERROR(status, "calling AudioQueueAddPropertyListener, status: %ld", (long)status);
    
    // allocate buffers
    // buffer size, one buffers for one second data
    int oneBufferSize = mFormat.mSampleRate*(format.mBitsPerChannel/8)*format.mChannelsPerFrame*kBufferDurationSeconds; // amr_nb:16000 amr_wb:32000
    for (int i = 0; i < kNumberRecordBuffers; i++) {
        status = AudioQueueAllocateBuffer(mQueue, oneBufferSize, &mBuffers[i]);
        LOG_IF_ERROR(status, "calling audio AudioQueueAllocateBuffer, status: %ld", (long)status);
        mAvailableBufferQueue.push_back(mBuffers[i]);
    }
}

#pragma mark - decode amr data to pcm
void AmrAQPlayer::DecodeDataToQueue() {
    // 每个buffer装kBufferDurationSeconds秒数据
    int oneBufferByteSize = mDecodeSession->ByteSizeOfOneFrame() * AMR_FRAME_COUNT_PER_SECOND * kBufferDurationSeconds;
    while (mAvailableBufferQueue.size() > 0 && mAmrBuffer.size() > 0) {
        AudioQueueBufferRef outBuffer = mAvailableBufferQueue.front();
        oneBufferByteSize = mAmrBuffer.size() < oneBufferByteSize ? (int)mAmrBuffer.size() : oneBufferByteSize;
        // decode data, and fill to the buffer
        outBuffer->mAudioDataByteSize = mDecodeSession->Decode(reinterpret_cast<const unsigned char*>(mAmrBuffer.data()), reinterpret_cast<short*>(outBuffer->mAudioData), oneBufferByteSize);
        // erase the data
        mAmrBuffer.erase(mAmrBuffer.begin(), mAmrBuffer.begin() + oneBufferByteSize);
        mAvailableBufferQueue.pop_front();
        OSStatus status = AudioQueueEnqueueBuffer(mQueue, outBuffer, 0, NULL);
        LOG_IF_ERROR(status, "calling audio AudioQueueEnqueueBuffer, status: %ld", (long)status);
    }
    if (mAmrBuffer.size() == 0) {
        OSStatus status = AudioQueueStop(mQueue, false); // false，播完准备好的buffer才结束
        LOG_IF_ERROR(status, "calling audio AudioQueueStop, status: %ld", (long)status);
    }
}

#pragma mark - AudioQueue callback
// ____________________________________________________________________________________
// called when the audio queue has finished playing a buffer.
void AmrAQPlayer::OutputBufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer) {
    AmrAQPlayer *THIS = (AmrAQPlayer *)inUserData;
    LOG_IF_DEBUG("OutputBufferCallback mIsUserRunning: %d ", THIS->mIsUserRunning);
    if (!THIS->mIsUserRunning) {
        return;
    }
    THIS->mListener->OneBufferPlayed();
    THIS->mAvailableBufferQueue.push_back(inCompleteAQBuffer);
    THIS->DecodeDataToQueue();
}

void AmrAQPlayer::IsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    AmrAQPlayer *THIS = (AmrAQPlayer *)inUserData;
    UInt32 size = sizeof(THIS->mIsRunning);
    UInt32 isRunning = 0;
    OSStatus status = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &isRunning, &size);
    LOG_IF_ERROR(status, "calling audio AudioQueueGetProperty, status: %ld", (long)status);
    if (status == noErr) {
        LOG_IF_DEBUG("IsRunningCallback, old status: %ld new status: %ld", (unsigned long)(THIS->mIsRunning), (long)isRunning);
        THIS->mIsRunning = isRunning;
        if (THIS->Listener()) {
            if (THIS->mIsRunning) {
                THIS->Listener()->PlaybackStateChanged(AmrAudioStateRunning);
            } else {
                THIS->Listener()->PlaybackStateChanged(AmrAudioStateStopped);
            }
        }
    }
}

#pragma mark - writebuffer 播放的amr数据
void AmrAQPlayer::WriteBuffer(const unsigned char *amr, int len) {
    mAmrBuffer.append(reinterpret_cast<const char*>(amr), len);
    DecodeDataToQueue();
}

#pragma mark - start/stop/pause/resume queue
bool AmrAQPlayer::StartQueue() {
    if (!mIsInitialized) {
        InitPlayer();
    }
    
    mIsUserRunning = true;
    OSStatus status = AudioQueueStart(mQueue, NULL);
    LOG_IF_ERROR(status, "calling audio queue start, status: %ld", (long)status);
    return status;
}

void AmrAQPlayer::StopQueue() {
    if (mQueue) {
        AudioQueueStop(mQueue, true);
    }
}

void AmrAQPlayer::PauseQueue() {
    // not test
    AudioQueuePause(mQueue);
}

void AmrAQPlayer::ResumeQueue() {
    // not test
    AudioQueueStart(mQueue, NULL);
}

void AmrAQPlayer::DisposeQueue() {
    LOG_IF_DEBUG("<<<<<<<<<< [DisposeQueue] mAmrBuffer.size() = %ld", mAmrBuffer.size());
    mIsUserRunning = false;
    mIsInitialized = false;
    mIsRunning = false;
    // 清空数据
    cleanUpAudioQueue();
}

void AmrAQPlayer::cleanUpAudioQueue()
{
    if (mQueue) {
        AudioQueueRemovePropertyListener(mQueue, kAudioQueueProperty_IsRunning, IsRunningCallback, this);
        for (int i = 0; i < kNumberRecordBuffers; i++) {
            AudioQueueFreeBuffer(mQueue, mBuffers[i]);
        }
        AudioQueueDispose(mQueue, true);
        mQueue = NULL;
    }
    mAmrBuffer.clear();
    mAvailableBufferQueue.clear();
}

int AmrAQPlayer::getPlaySeconds(int dataLength) {
    return ceil(((float)dataLength / mDecodeSession->ByteSizeOfOneFrame()) / AMR_FRAME_COUNT_PER_SECOND);
}

int AmrAQPlayer::getPlayDataOffset(int offsetSeconds) {
    return ceil(AMR_FRAME_COUNT_PER_SECOND*offsetSeconds*mDecodeSession->ByteSizeOfOneFrame());
}

/*
#pragma mark - level Meter 录播是一样的，代码冗余，二次设计可以统一下？已统一到 AQLevelMeterReporter ANDYYU:
void AmrAQPlayer::InitLevelMeter() {
    if (mChannelLevels == NULL) {
        mChannelLevels = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState)*NUMBER_OF_CHANNELS);
    }
    if (mMeterTable == NULL) {
        mMeterTable = new MeterTable(kMinDBvalue);
    }
}

OSErr AmrAQPlayer::GetLevelMeter() {
    InitLevelMeter();
    UInt32 data_sz = sizeof(AudioQueueLevelMeterState);
    OSErr status = AudioQueueGetProperty(mQueue,
                                         kAudioQueueProperty_CurrentLevelMeterDB,
                                         mChannelLevels,
                                         &data_sz);
    return status;
}

float AmrAQPlayer::GetChannelLevel(int channel) {
    return mMeterTable->ValueAt((float)(mChannelLevels[channel].mAveragePower));
}

bool AmrAQPlayer::isQueueExsit() {
    return (mQueue == NULL) ? false : true;
}

bool AmrAQPlayer:: isChannelExsit()
{
    return (mChannelLevels == NULL) ? false : true;
}
 */
