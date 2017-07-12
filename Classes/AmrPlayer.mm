//
//  AmrPlayer.m
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//x

#import "AmrPlayer.h"
#import "AmrAQPlayer.h"
#import "AmrAudioConfig.h"
#import "AmrCodecDefine.h"
#import "AudioSessionManager.h"
#import "AQLevelMeterReporter.h"
#import "AmrSessionCommon.h"
#import <UIKit/UIKit.h>
#import <ZHLogger/LumberjackLog.h>

@interface AmrPlayer(AmrAQPlayerCallback)

- (void)onPlaybackStateChanged:(AmrAudioState)state;
- (void)onOneBufferPlayed;

@end

#pragma mark - fooAQPlayerCallback C++ <--> Objective-C
class fooAQPlayerCallback : public IAmrAQPlayerListener
{
private:
    AmrPlayer *_player;
public:
    fooAQPlayerCallback(AmrPlayer *player)
    {
        _player = player;
    }
    
    void PlaybackStateChanged(AmrAudioState state)
    {
        [_player onPlaybackStateChanged:state];
    }
    
    void OneBufferPlayed()
    {
        [_player onOneBufferPlayed];
    }
};

@interface AmrPlayer() {
    fooAQPlayerCallback     *_listener;
    AmrAQPlayer             *_player;
    // for AudioSession
    BOOL                    _playbackWasInterrupted;
    BOOL                    _playerPaused;
    AQLevelMeterReporter    *_levelMeterReporter;
    NSString *_currentPlayFileName;
}
@end

@implementation AmrPlayer

@synthesize delegate;

//SYNTHESIZE_SINGLETON_FOR_CLASS(AmrPlayer);

static AmrPlayer *sharedAmrPlayer = nil;

+ (AmrPlayer *)sharedAmrPlayer
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedAmrPlayer = [[AmrPlayer alloc] init];
    });
    return sharedAmrPlayer;
}

- (AmrPlayer *)init
{
    self = [super init];
    if (self) {
        _listener = new fooAQPlayerCallback(self);
        _player = new AmrAQPlayer();
        _player->SetListener(_listener);
        
//        [[AudioSessionManager sharedAudioSessionManager] start];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"TY_CLOSE_UIDeviceProximityStateDidChangeNotification"]) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(proximityChanged:)
                                                         name:UIDeviceProximityStateDidChangeNotification
                                                       object:nil];

        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentRouteChanged:)
                                                     name:kAudioSessionRouteChangeNotification
                                                   object:[AudioSessionManager sharedAudioSessionManager]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterruption:)
                                                     name:kAudioSessionInterruptionNotification
                                                   object:[AudioSessionManager sharedAudioSessionManager]];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_levelMeterReporter setAq:NULL withNotifyKey:nil];
    [_levelMeterReporter release], _levelMeterReporter = nil;
    [_currentPlayFileName release], _currentPlayFileName = nil;
    if (_player) {
        delete _player;
        _player = NULL;
    }
    if (_listener) {
        delete _listener;
        _listener = NULL;
    }
    [super dealloc];
}

#pragma mark - public methods
- (void)setPlayerCodecType:(AmrCodecType)codecType Mode:(int)mode
{
    [[AudioSessionManager sharedAudioSessionManager] start];
    _player->InitPlayer(codecType, mode);
}

- (int)playFile:(NSString *)fileName interval:(NSTimeInterval)interval
{
    NSData *data = [[NSData dataWithContentsOfFile:fileName] retain];
    if (!data || [data length] <= 9) {
        LogError(kErrorIO,@"读取文件数据失败，文件不存在或损坏, fileName:%@, data:%@", fileName, data);
//        LOG_IF_DEBUG("ERROR: file not exist or bad, %s", [fileName UTF8String]);
        [data release];
        return 0;
    }
    if (_player->IsUserRunning()) {
        [self stopQueue];
    }
    
    NSUInteger dataLength = [data length];
    const char* p = reinterpret_cast<const char*>([data bytes]);
    if (0 == memcmp(p, AMR_NB_MAGIC_NUMBER, 6)) {
        p += 6;
        dataLength -= 6;
        
        [[AudioSessionManager sharedAudioSessionManager] start];
        _player->InitPlayer(amr_nb);
    }
    if (0 == memcmp(p, AMR_WB_MAGIC_NUMBER, 6)) {
        p += 9;
        dataLength -= 9;
        
        [[AudioSessionManager sharedAudioSessionManager] start];
        _player->InitPlayer(amr_wb);
    }

    _currentPlaySeconds = interval;
    _currentFrameCount = interval * AMR_FRAME_COUNT_PER_SECOND;

    int offset = _player->getPlayDataOffset(interval);
    if ( offset >= dataLength ) {
        offset = 0;
    }
    p += offset;
    NSData *amrData = [[NSData dataWithBytes:p length:(dataLength - offset)] retain];
    [data release];
    [self appendData:amrData];

    int playSeconds = _player->getPlaySeconds((unsigned int)dataLength - offset);
    [amrData release];
    
    [_currentPlayFileName release];
    _currentPlayFileName = [fileName copy];
    return playSeconds;
}

- (int)playFile:(NSString *)fileName
{
    return [self playFile:fileName interval:0];
}

- (void)appendData:(NSData *)data
{
    if (!data || [data length] <= 0) {
        return;
    }
    if (!_player->IsRunning()) {
        [self startQueue];
    }
    _player->WriteBuffer((const unsigned char *)[data bytes], (unsigned int)[data length]);
}

- (void)startQueue
{
    [[AudioSessionManager sharedAudioSessionManager] setActive:NO];//先关掉一次会话，针对问题：招行后台录音，在我们播放语音时关不掉
    
    [[AudioSessionManager sharedAudioSessionManager] setActive:YES];
    [[AudioSessionManager sharedAudioSessionManager] setAudioRouteWithSpeaker:[AudioSessionManager sharedAudioSessionManager].defaultToSpeaker];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    _player->StartQueue();
    [_levelMeterReporter setAq:_player->Queue() withNotifyKey:nil];
}

- (void)stopQueue
{
    [_currentPlayFileName release], _currentPlayFileName = nil;
    [_levelMeterReporter setAq:NULL withNotifyKey:nil];
    _player->DisposeQueue();
    [[AudioSessionManager sharedAudioSessionManager] setActive:NO];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
}

- (void)stop
{
    [self onPlaybackStateChanged:AmrAudioStateStopped];
}

- (void)pause
{
    _playerPaused = _player->IsRunning();
    if ( _playerPaused ) {
        _player->PauseQueue();
    }
}

- (void)resume
{
    if ( _playerPaused ) {
        _player->ResumeQueue();
    }
}

- (NSString *)currentPlayFileName
{
    if (_player->IsRunning()) {
        return _currentPlayFileName;
    }
    return nil;
}

- (int)getPlaySecondsOfFile:(NSString *)fileName amrnbMode:(AmrnbMode)amrnbMode
{
    int res = 0;
    
    NSData *data = [[NSData dataWithContentsOfFile:fileName] retain];
    if (!data || [data length] <= 9) {
        LogError(kErrorIO,@"读取文件数据失败，文件不存在或损坏, fileName:%@, data:%@", fileName, data);
//        LOG_IF_DEBUG("ERROR: file not exist or bad, %s", [fileName UTF8String]);
        [data release];
        return 0;
    }
    const char* p = reinterpret_cast<const char*>([data bytes]);
    if (0 == memcmp(p, AMR_NB_MAGIC_NUMBER, 6)) {
        // 去掉文件头
        res = [self getPlaySecondsOfFileSize:(data.length - 6) amrnbMode:amrnbMode];
    } else if (0 == memcmp(p, AMR_WB_MAGIC_NUMBER, 9)) {
        // not support the AMR_WB!
        ASSERT_IF_DEBUG(0);
        res = [self getPlaySecondsOfFileSize:(data.length - 9) amrwbMode:(AmrwbMode)amrnbMode];
    } else {
        res = [self getPlaySecondsOfFileSize:data.length amrnbMode:amrnbMode];
    }
    [data release];
    
    return res;
}

- (int)getPlaySecondsOfFileSize:(long long )dataLength amrnbMode:(AmrnbMode)amrnbMode
{
    return ceil(((float)dataLength / AmrSessionCommon::ByteSizeOfOneFrameAMRNB(amrnbMode)) / AMR_FRAME_COUNT_PER_SECOND);
}

- (int)getPlaySecondsOfFileSize:(long long )dataLength amrwbMode:(AmrwbMode)amrwbMode
{
    return ceil(((float)dataLength / AmrSessionCommon::ByteSizeOfOneFrameAMRWB(amrwbMode)) / AMR_FRAME_COUNT_PER_SECOND);
}

// 启用语音波形
- (void)openLevelMeterWithNotifyKey:(NSString *)notifyKey
{
    if (!_levelMeterReporter) {
        _levelMeterReporter = [[AQLevelMeterReporter alloc] init];
    }
    [_levelMeterReporter setAq:_player->Queue() withNotifyKey:notifyKey];
}

#pragma mark - for AudioSession
- (BOOL)isRunning
{
    return _player->IsUserRunning();
}

- (BOOL)playbackWasInterrupted
{
    return _player->playbackWasInterrupted();
}

- (void)setPlaybackWasInterrupted:(BOOL)interrupt
{
    _player->setPlaybackWasInterrupted(interrupt);
}

#pragma mark - 接近传感器监测(挪到AudioSessionManager管理是否更合理?)
-(void)proximityChanged:(NSNotification *)notification
{
    if (![self isRunning]) {
        return;
    }
    LOG_IF_DEBUG("In proximity: %i", [UIDevice currentDevice].proximityState);
    if ([UIDevice currentDevice].proximityState == YES) {
        [[AudioSessionManager sharedAudioSessionManager] setAudioRouteWithSpeaker:NO];
    } else {
        [[AudioSessionManager sharedAudioSessionManager] setAudioRouteWithSpeaker:[AudioSessionManager sharedAudioSessionManager].defaultToSpeaker];
    }
}

- (void)currentRouteChanged:(NSNotification *)notification
{
    if (![self isRunning]) {
        return;
    }
    
    NSInteger reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory: {
        }
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep: {
        }
            break;
        case AVAudioSessionRouteChangeReasonOverride: {
        }
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange: {
        }
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
            // LOG_IF_DEBUG("AVAudioSessionRouteChangeReasonOldDeviceUnavailable");
            [[AudioSessionManager sharedAudioSessionManager] setAudioRouteWithSpeaker:[AudioSessionManager sharedAudioSessionManager].defaultToSpeaker];
        }
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
            // LOG_IF_DEBUG("AVAudioSessionRouteChangeReasonNewDeviceAvailable");
            [[AudioSessionManager sharedAudioSessionManager] setAudioRouteWithSpeaker:[AudioSessionManager sharedAudioSessionManager].defaultToSpeaker];
        }
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default: {
        }
            break;
    }
}

- (void)audioSessionInterruption:(NSNotification *)notification
{
    /*AVAudioSessionInterruptionType*/NSInteger interruptionType = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType) {
        LOG_IF_DEBUG("kAudioSessionBeginInterruption");
		if ([self isRunning]) {
            // the queue will stop itself on an interruption, we just need to update the UI
            if (self.delegate && [self.delegate respondsToSelector:@selector(OnPlaybackStateChanged:)]) {
                [self.delegate onPlaybackStateChanged:AmrAudioStateStopped player:self];
            }
            [self setPlaybackWasInterrupted:YES];
		}
    } else if (AVAudioSessionInterruptionTypeEnded == interruptionType) {
        LOG_IF_DEBUG("kAudioSessionEndInterruption");
        if ([self playbackWasInterrupted]) {
            // we were playing back when we were interrupted, so reset and resume now
            [self startQueue];
            [self setPlaybackWasInterrupted:NO];
        }
    }
}

#pragma mark - AmrAQPlayer callback
- (void)onPlaybackStateChanged:(AmrAudioState)state
{
    if (state == AmrAudioStateStopped || state == AmrAudioStateError) {
        [self performSelector:@selector(stopQueue)
                     onThread:[NSThread currentThread]
                   withObject:nil
                waitUntilDone:YES];
    }
    if (delegate && [delegate respondsToSelector:@selector(onPlaybackStateChanged:player:)]) {
        [delegate onPlaybackStateChanged:state player:self];
    }
}

- (void)onOneBufferPlayed
{
    _currentPlaySeconds++;
    _currentFrameCount += AMR_FRAME_COUNT_PER_SECOND;
    if (delegate && [delegate respondsToSelector:@selector(onOneBufferPlayed:)]) {
        [delegate onOneBufferPlayed:self];
    }
}

#pragma mark - 语音波形  将来需要再加

@end
