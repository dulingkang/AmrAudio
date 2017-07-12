//
//  AQLevelMeter.cpp
//  SpeakHereAmr
//
//  Created by YuGuangzhen on 13-7-17.
//  Copyright (c) 2013年 YuGuangzhen. All rights reserved.
//

#import "AQLevelMeterReporter.h"
#include "MeterTable.h"
#include "AmrAudioConfig.h"

@implementation AQLevelMeterReporter

- (id)init {
	if (self = [super init]) {
		_refreshHz = kRefreshHz;
		_channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
		_chan_lvls = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState) * [_channelNumbers count]);
		_meterTable = new MeterTable(kMinDBvalue);
        _notifyKey = [[NSString alloc] initWithString:kNotifyLevelMeter];
        [self setSubLevelMeters];
	}
	return self;
}

- (void)dealloc {
	[_updateTimer invalidate], _updateTimer = nil;
	[_channelNumbers release], _channelNumbers = nil;
	[_subLevelMeters release], _subLevelMeters = nil;
	[_notifyKey release], _notifyKey = nil;
    
    _aq = nil;
	
	if (_meterTable) {
        delete _meterTable;
        _meterTable = NULL;
    }
    if (_chan_lvls) {
        free(_chan_lvls);
        _chan_lvls = NULL;
    }
	[super dealloc];
}

- (void)setSubLevelMeters {
    [_subLevelMeters release];
    NSMutableArray *meters_build = [[NSMutableArray alloc] initWithCapacity:[_channelNumbers count]];
    for (int i = 0; i < [_channelNumbers count]; i++) {
        NSMutableDictionary *channelLevel = [NSMutableDictionary dictionary];
        [channelLevel setObject:[NSNumber numberWithFloat:0.] forKey:kLevelValue];
        [channelLevel setObject:[NSNumber numberWithInt:i] forKey:kChannelIndex];
        [meters_build addObject:channelLevel];
    }
	_subLevelMeters = [[NSArray alloc] initWithArray:meters_build];
	[meters_build release];
}

- (void)_refresh
{
	BOOL success = NO;
    
	// if we have no queue, but still have levels, gradually bring them down
	if (_aq == NULL)
	{
		CGFloat maxLvl = -1.;
		CFAbsoluteTime thisFire = CFAbsoluteTimeGetCurrent();
		// calculate how much time passed since the last draw
		CFAbsoluteTime timePassed = thisFire - _peakFalloffLastFire;
		for (NSMutableDictionary *thisLevel in _subLevelMeters)
		{
			CGFloat newLevel;
			newLevel = [[thisLevel objectForKey:kLevelValue] floatValue] - timePassed * kLevelFalloffPerSec;
			if (newLevel < 0.) {
                newLevel = 0.;
            }
            [thisLevel setObject:[NSNumber numberWithFloat:newLevel] forKey:kLevelValue];
            if (newLevel > maxLvl) {
                maxLvl = newLevel;
            }
            [self performSelectorOnMainThread:@selector(reportLevelMeter:) withObject:thisLevel waitUntilDone:NO];
		}
		// stop the timer when the last level has hit 0
		if (maxLvl <= 0.)
		{
			[_updateTimer invalidate];
			_updateTimer = nil;
		}
		
		_peakFalloffLastFire = thisFire;
		success = YES;
	} else {
		UInt32 data_sz = sizeof(AudioQueueLevelMeterState) * (UInt32)[_channelNumbers count];
		OSErr status = AudioQueueGetProperty(_aq, kAudioQueueProperty_CurrentLevelMeterDB, _chan_lvls, &data_sz);
        LOG_IF_ERROR(status, "calling audio AudioQueueGetProperty, status: %d", status);
		if (status != noErr) goto bail;
        
		for (int i=0; i<[_channelNumbers count]; i++)
		{
			NSInteger channelIdx = [(NSNumber *)[_channelNumbers objectAtIndex:i] intValue];
			NSMutableDictionary *channelLevel = [_subLevelMeters objectAtIndex:channelIdx];
			
			if (channelIdx >= [_channelNumbers count]) goto bail;
			if (channelIdx > 127) goto bail;
			
			if (_chan_lvls)
			{
				CGFloat level = _meterTable->ValueAt((float)(_chan_lvls[channelIdx].mAveragePower));
                [channelLevel setObject:[NSNumber numberWithFloat:level] forKey:kLevelValue];
                [self performSelectorOnMainThread:@selector(reportLevelMeter:) withObject:channelLevel waitUntilDone:NO];
				success = YES;
			}
		}
	}
	
bail:
	
	if (!success)
	{
		for (NSMutableDictionary *channelLevel in _subLevelMeters) {
            [channelLevel setObject:[NSNumber numberWithFloat:0.] forKey:kLevelValue];
            [self performSelectorOnMainThread:@selector(reportLevelMeter:) withObject:channelLevel waitUntilDone:NO];
        }
		LOG_IF_DEBUG("ERROR: metering failed\n");
	}
}

- (void)reportLevelMeter:(NSDictionary *)channelLevel {
    [[NSNotificationCenter defaultCenter] postNotificationName:_notifyKey object:nil userInfo:channelLevel];
}

//- (AudioQueueRef)aq { return _aq; }
- (void)setAq:(AudioQueueRef)v withNotifyKey:(NSString *)notifyKey
{
    if (notifyKey) {
        [_notifyKey release];
        _notifyKey = [notifyKey retain];
    }
	if ((_aq == NULL) && (v != NULL))
	{
		if (_updateTimer) [_updateTimer invalidate];
		
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(_refresh)
						userInfo:nil
						repeats:YES
						];
	} else if ((_aq != NULL) && (v == NULL)) {
		_peakFalloffLastFire = CFAbsoluteTimeGetCurrent();
	}
	
	_aq = v;
	
	if (_aq)
	{
        UInt32 val = 1;
        OSStatus status = AudioQueueSetProperty(_aq, kAudioQueueProperty_EnableLevelMetering, &val, sizeof(UInt32));
        LOG_IF_ERROR(status, "couldn't enable metering");
        // now check the number of channels in the new queue, we will need to reallocate if this has changed
        AudioStreamBasicDescription queueFormat;
        UInt32 data_sz = sizeof(queueFormat);
        status = AudioQueueGetProperty(_aq, kAudioQueueProperty_StreamDescription, &queueFormat, &data_sz);
        LOG_IF_ERROR(status, "couldn't get stream description");
        
        if (queueFormat.mChannelsPerFrame != [_channelNumbers count])
        {
            NSArray *chan_array;
            if (queueFormat.mChannelsPerFrame < 2) {
                chan_array = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
            } else {
                chan_array = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], [NSNumber numberWithInt:1], nil];
            }
            [self setChannelNumbers:chan_array];
            [chan_array release];
            
            _chan_lvls = (AudioQueueLevelMeterState*)realloc(_chan_lvls, queueFormat.mChannelsPerFrame * sizeof(AudioQueueLevelMeterState));
        }
		
    } else {
		for (NSMutableDictionary *channelLevel in _subLevelMeters) {
            [self performSelectorOnMainThread:@selector(reportLevelMeter:) withObject:channelLevel waitUntilDone:NO];
        }
	}
}

- (CGFloat)refreshHz { return _refreshHz; }
- (void)setRefreshHz:(CGFloat)v
{
	_refreshHz = v;
	if (_updateTimer)
	{
		[_updateTimer invalidate];
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(_refresh)
						userInfo:nil
						repeats:YES
						];
	}
}

//- (NSArray *)channelNumbers { return _channelNumbers; }
- (void)setChannelNumbers:(NSArray *)v {
	[v retain];
	[_channelNumbers release];
	_channelNumbers = v;
	[self setSubLevelMeters];
}

@end
