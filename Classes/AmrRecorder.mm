//
//  AmrRecorder.m
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-13.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import "AmrRecorder.h"
#include "AmrAQRecorder.h"
#import "AmrAudioConfig.h"
#import "AudioSessionManager.h"
#import <CoreGraphics/CGBase.h>
#import "AQLevelMeterReporter.h"
#import "LumberjackLog.h"

@interface AmrRecorder(AmrAQRecorderCallback)

- (void)onRecordingStateChanged:(AmrAudioState)state;
- (void)onInputBufferReceived:(NSData *)data isFullBuffer:(BOOL)isFull;

@end

#pragma mark - fooAQRecorderCallback C++ <--> Objective-C
class fooAQRecorderCallback : public IAmrAQRecorderListener
{
private:
    AmrRecorder* _recoder;

public:
    fooAQRecorderCallback(AmrRecorder * recoder)
    {
        _recoder = recoder;
    }

    void RecordingStateChanged(AmrAudioState state)
    {
        [_recoder onRecordingStateChanged:state];
    }
    
    void InputBufferReceived(const unsigned char* amr, int len, bool isFullBuffer)
    {
        [_recoder onInputBufferReceived:[NSData dataWithBytes:amr length:len] isFullBuffer:isFullBuffer];
    }
};

@interface AmrRecorder()
{
    FILE                    *_file;
    fooAQRecorderCallback   *_listener;
    AmrAQRecorder           *_recorder;
    // 语音波形
    AQLevelMeterReporter    *_levelMeterReporter;
}

- (void)openFile:(NSString *)fileName;
- (void)closeFile;

@end

//@interface AmrRecorder(levelMeter)
//
//- (void)setMeterLevel;
//- (void)_refresh;
//- (void)onLevelMeter:(float)level;
//
//@end

@implementation AmrRecorder

// SYNTHESIZE_SINGLETON_FOR_CLASS(AmrRecorder);
static AmrRecorder *sharedAmrRecorder = nil;

+ (AmrRecorder *)sharedAmrRecorder
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedAmrRecorder = [[AmrRecorder alloc] init];
    });
    return sharedAmrRecorder;
}

@synthesize delegate;

- (AmrRecorder *)init
{
    self = [super init];
    if (self) {
        // Ensure the amr record root folder exists
        NSString *folderPath = AMR_RECORD_ROOT_FOLDER;
        if (![[NSFileManager defaultManager] fileExistsAtPath:folderPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        }

        _file = NULL;
        _listener = new fooAQRecorderCallback(self);
        _recorder = new AmrAQRecorder();
        _recorder->SetListener(_listener);
        
        //启动波形
        [self openLevelMeterWithNotifyKey:nil];
//        _level = 0.;
//        _refreshHz = 1/30.;
//        // 准确的说，这里缺少多声道波形的逻辑。 只取了第一个声道的波形（我们的amr时单声道的，所以足够）
//        _channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
        
        [[AudioSessionManager sharedAudioSessionManager] start];

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
    self.delegate = nil;
    [self closeFile];
    
    [_levelMeterReporter setAq:NULL withNotifyKey:nil];
    [_levelMeterReporter release], _levelMeterReporter = nil;
    
    if (_recorder) {
        delete _recorder;
        _recorder = NULL;
    }
    if (_listener) {
        delete _listener;
        _listener = NULL;
    }
//    [_channelNumbers release];
//    [_updateTimer release];
    
    [super dealloc];
}

#pragma mark - public methods
- (void)setRecorderCodecType:(AmrCodecType)codecType Mode:(int)mode
{
    _recorder->InitRecorder(codecType, mode);
}

- (void)startWithRecordFileName:(NSString *)fileName
{
    // close previous file
    [self closeFile];
    if (fileName) {
        //NSString *filePath = [NSString stringWithFormat:@"%@/%@", AMR_RECORD_ROOT_FOLDER, fileName];
        [self openFile:fileName];
    }
    [[AudioSessionManager sharedAudioSessionManager] changeMode:kAudioSessionManagerMode_Record];
    _recorder->Start();
    [_levelMeterReporter setAq:_recorder->Queue() withNotifyKey:nil];
}

- (void)stop
{
    [_levelMeterReporter setAq:NULL withNotifyKey:nil];
    _recorder->Stop();
    [[AudioSessionManager sharedAudioSessionManager] changeMode:kAudioSessionManagerMode_Playback];
    [[AudioSessionManager sharedAudioSessionManager] setActive:NO];
}

// 启用语音波形
- (void)openLevelMeterWithNotifyKey:(NSString *)notifyKey
{
    if (!_levelMeterReporter) {
        _levelMeterReporter = [[AQLevelMeterReporter alloc] init];
    }
    [_levelMeterReporter setAq:_recorder->Queue() withNotifyKey:notifyKey];
}

- (BOOL)isRunning
{
    return _recorder->IsRunning();
}

#pragma mark - notification methods
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
        }
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
        }
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default: {
            if ([self isRunning]) {
                [self stop];
            }
        }
            break;
    }
}

- (void)audioSessionInterruption:(NSNotification *)notification
{
    /*AVAudioSessionInterruptionType*/NSInteger interruptionType = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (AVAudioSessionInterruptionTypeBegan == interruptionType) {
		if ([self isRunning]) {
			[self stop];
		}
    } else if (AVAudioSessionInterruptionTypeEnded == interruptionType) {
    }
}

#pragma mark - private methods
- (void)openFile:(NSString *)fileName
{
    FILE * file = fopen([fileName UTF8String], "wb"); // 若文件存在，旧文件将被清掉
    if (file) {
        _file = file;
//        fwrite("#!AMR\n", 1, 6, _file); // 写文件头，只支持amr_nb
    } else {
        LogError(kErrorIO,@"打开文件失败, fileName:%@", fileName);
//        LOG_IF_DEBUG("ERROR: open file failed, fileName: %s", [fileName UTF8String]);
        ASSERT_IF_DEBUG(0);
    }
}

- (void)closeFile
{
    if (_file) {
        fclose(_file);
        _file = NULL;
    }
}

#pragma mark - AmrAQRecorder callback
- (void)onRecordingStateChanged:(AmrAudioState)state
{
    if (state == AmrAudioStateStopped) {
        // close file
        [self closeFile];
    }
    
    // delegate
    if (delegate && [delegate respondsToSelector:@selector(onRecordingStateChanged:recorder:)]) {
        [delegate onRecordingStateChanged:state recorder:self];
    }
    
    // TODO: block interface?
}

- (void)onInputBufferReceived:(NSData *)data isFullBuffer:(BOOL)isFull
{
    // delegate
    if (delegate && [delegate respondsToSelector:@selector(onInputBufferReceived:isFullBuffer:recorder:)]) {
        [delegate onInputBufferReceived:data isFullBuffer:isFull recorder:self];
    }
    
    // TODO: block interface?
    
    // write to file
    if (_file) {
        fseek(_file, 0, SEEK_END);
        fwrite([data bytes], [data length], 1, _file);
    }
}

/*
#pragma mark - level meter info 语音波形 ANDYYU:统一到AQLevelMeterReporter

- (void)setMeterLevel
{
    if (_recorder->isQueueExsit())
	{
        _aqIsExit = YES;
		[_updateTimer invalidate];
        [_updateTimer release];
		_updateTimer = [[NSTimer
                         scheduledTimerWithTimeInterval:_refreshHz
                         target:self
                         selector:@selector(_refresh)
                         userInfo:nil
                         repeats:YES
                         ] retain];
	}
    else
    {
		_peakFalloffLastFire = CFAbsoluteTimeGetCurrent();
        _aqIsExit = NO;
        NSNumber *aqIsExitNum = [NSNumber numberWithBool:_aqIsExit];
        NSNumber *levelNum = [NSNumber numberWithFloat:_level];
        NSMutableDictionary *param = [NSMutableDictionary dictionaryWithCapacity:0];
        [param setObject:aqIsExitNum forKey:@"aqIsExitNum"];
        [param setObject:levelNum forKey:@"levelNum"];
        [self performSelectorOnMainThread:@selector(RefreshUI:) withObject:param waitUntilDone:NO];
    }
}

- (void)_refresh
{
	// if we have no queue, but still have levels, gradually bring them down
    BOOL success = NO;
	if (!_recorder->isQueueExsit())
	{
        _aqIsExit = NO;
		CGFloat maxLvl = -1.;
		CFAbsoluteTime thisFire = CFAbsoluteTimeGetCurrent();
		// calculate how much time passed since the last draw
		CFAbsoluteTime timePassed = thisFire - _peakFalloffLastFire;

		CGFloat  newLevel;
        newLevel = _level - timePassed * kLevelFalloffPerSec;
        if (newLevel < 0.)
            newLevel = 0.;
        _level = newLevel;
        if (newLevel > maxLvl)
            maxLvl = newLevel;

        NSNumber *aqIsExitNum = [NSNumber numberWithBool:_aqIsExit];
        NSNumber *levelNum = [NSNumber numberWithFloat:_level];
        NSMutableDictionary *param = [NSMutableDictionary dictionaryWithCapacity:0];
        [param setObject:aqIsExitNum forKey:@"aqIsExitNum"];
        [param setObject:levelNum forKey:@"levelNum"];
        [self performSelectorOnMainThread:@selector(RefreshUI:) withObject:param waitUntilDone:NO];

		// stop the timer when the last level has hit 0

        if (maxLvl <= 0.)
		{
			[_updateTimer invalidate];
            [_updateTimer release];
			_updateTimer = nil;
		}

		_peakFalloffLastFire = thisFire;
        success = YES;
	}
    else
    {
        _aqIsExit = YES;
        OSErr status = _recorder->GetLevelMeter();
        if (status != noErr) goto bail;

		for (int i=0; i<[_channelNumbers count]; i++)
		{
			NSInteger channelIdx = [(NSNumber *)[_channelNumbers objectAtIndex:i] intValue];
			if (channelIdx >= [_channelNumbers count]) goto bail;
			if (channelIdx > 127) goto bail;

            if (_recorder->isChannelExsit()) {
                _level = _recorder->GetChannelLevel(i);
                NSNumber *aqIsExitNum = [NSNumber numberWithBool:_aqIsExit];
                NSNumber *levelNum = [NSNumber numberWithFloat:_level];
                NSMutableDictionary *param = [NSMutableDictionary dictionaryWithCapacity:0];
                [param setObject:aqIsExitNum forKey:@"aqIsExitNum"];
                [param setObject:levelNum forKey:@"levelNum"];
                [self performSelectorOnMainThread:@selector(RefreshUI:) withObject:param waitUntilDone:NO];success = YES;
            }
		}
	}

bail:
    if (!success)
    {
        NSNumber *aqIsExitNum = [NSNumber numberWithBool:_aqIsExit];
        NSNumber *levelNum = [NSNumber numberWithFloat:_level];
        NSMutableDictionary *param = [NSMutableDictionary dictionaryWithCapacity:0];
        [param setObject:aqIsExitNum forKey:@"aqIsExitNum"];
        [param setObject:levelNum forKey:@"levelNum"];
        [self performSelectorOnMainThread:@selector(RefreshUI:) withObject:param waitUntilDone:NO];
    }
}

- (void)refreshUI:(NSDictionary *)param
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"notifyAudioWave" object:nil userInfo:param];

    //[self OnLevelMeter:[[param objectForKey:@"levelNum"] floatValue]];
}

- (void)OnLevelMeter:(float)level 
{
    // delegate
    if (delegate && [delegate respondsToSelector:@selector(OnLevelMeter:)]) {
        [delegate OnRecordLevelMeter:level];
    }

    // TODO: block interface?
}
*/

@end


