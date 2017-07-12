
//
//  AudioSessionManager.m
//
//  Copyright 2011 Jawbone Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>
#import "AudioSessionManager.h"
#import "LumberjackLog.h"

// use normal logging if custom macros don't exist
#ifndef NSLogWarn
#define NSLogWarn NSLog
#endif

#ifndef NSLogError
#define NSLogError NSLog
#endif

#ifndef NSLogDebug
#define LOG_LEVEL 3
#define NSLogDebug(frmt, ...)    do{ if(LOG_LEVEL >= 4) NSLog((frmt), ##__VA_ARGS__); } while(0)
#endif

@interface AudioSessionManager () {	// private
	NSString	*mMode;
    
	BOOL		 mBluetoothDeviceAvailable;
	BOOL		 mHeadsetDeviceAvailable;
	BOOL         mDefaultToSpeaker;
    
	NSArray		*mAvailableAudioDevices;
    
    NSString    *_currentDeviceRoute;
    NSString    *_currentMode;

    BOOL        _isInitialized;
}

@property (nonatomic, assign)		BOOL			 bluetoothDeviceAvailable;
@property (nonatomic, assign)		BOOL			 headsetDeviceAvailable;
@property (nonatomic, strong)		NSArray			*availableAudioDevices;

@end

NSString *kAudioSessionManagerMode_Record           = @"AudioSessionManagerMode_Record";
NSString *kAudioSessionManagerMode_Playback         = @"AudioSessionManagerMode_Playback";

NSString *kAudioSessionManagerDevice_Headset        = @"AudioSessionManagerDevice_Headset";
NSString *kAudioSessionManagerDevice_Bluetooth      = @"AudioSessionManagerDevice_Bluetooth";
NSString *kAudioSessionManagerDevice_Phone          = @"AudioSessionManagerDevice_Phone";
NSString *kAudioSessionManagerDevice_Speaker        = @"AudioSessionManagerDevice_Speaker";

NSString *kAudioSessionRouteChangeNotification      = @"AudioSessionRouteChangeNotification";
NSString *kAudioSessionInterruptionNotification     = @"AudioSessionInterruptionNotification";
NSString *kAudioSessionDeviceChangedNotification    = @"AudioSessionDeviceChangedNotification";
NSString *kAudioSessionBluetoothDeviceAvailableNotification = @"AudioSessionBluetoothDeviceAvailableNotification";
NSString *kAudioSessionOldDeviceUnavailable         = @"AudioSessionOldDeviceUnavailable";
NSString *kAudioSessionNewDeviceAvailable           = @"AudioSessionNewDeviceAvailable";
NSString *kProximityStateDidChangeNotification      = @"ProximityStateDidChangeNotification";
NSString *kAppDefaultToSpeakerChangeNotification    = @"AppDefaultToSpeakerChangeNotification";

NSString *kAppScreenLockedNotification              = @"AppScreenLockedNotification";



@implementation AudioSessionManager

@synthesize headsetDeviceAvailable      = mHeadsetDeviceAvailable;
@synthesize bluetoothDeviceAvailable    = mBluetoothDeviceAvailable;
@synthesize availableAudioDevices       = mAvailableAudioDevices;
@synthesize defaultToSpeaker            = mDefaultToSpeaker;

//#pragma mark -
//#pragma mark Singleton
//
//#pragma mark - Singleton
//
//#define SYNTHESIZE_SINGLETON_FOR_CLASS(classname) \
//+ (classname*)sharedInstance { \
//static classname* __sharedInstance; \
//static dispatch_once_t onceToken; \
//dispatch_once(&onceToken, ^{ \
//__sharedInstance = [[classname alloc] init]; \
//}); \
//return __sharedInstance; \
//}

+ (AudioSessionManager *)sharedAudioSessionManager {
    static AudioSessionManager *sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
	if ((self = [super init])) {
		mMode = kAudioSessionManagerMode_Record;
        mDefaultToSpeaker = YES;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];
	}
    
	return self;
}

- (void)dealloc
{
    mMode = nil;
    mAvailableAudioDevices = nil;
    _currentDeviceRoute = nil;
    _currentMode = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark private functions

- (BOOL)configureAudioSessionWithDesiredAudioRoute:(NSString *)desiredAudioRoute
{
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *err = nil;
    
	// close down our current session...
    if ([[UIDevice currentDevice].systemVersion floatValue] < 8.0f) {
        [audioSession setActive:NO error:&err];
    }
	
    
    if ((mMode == kAudioSessionManagerMode_Record) && !audioSession.inputAvailable) {
        LogError(kErrorMedia, @"设备无录音权限/不支持录音");
		return NO;
    }

    /*
     * Need to always use AVAudioSessionCategoryPlayAndRecord to redirect output audio per
     * the "Audio Session Programming Guide", so we only use AVAudioSessionCategoryPlayback when
     * !inputIsAvailable - which should only apply to iPod Touches without external mics.
     */
    NSString *audioCat = (mMode == kAudioSessionManagerMode_Playback) ? AVAudioSessionCategoryPlayback : AVAudioSessionCategoryPlayAndRecord;
	if (![audioSession setCategory:audioCat withOptions:((desiredAudioRoute == kAudioSessionManagerDevice_Bluetooth) ? AVAudioSessionCategoryOptionAllowBluetooth : 0) error:&err]) {
        LogError(kErrorMedia, @"设置音频会话类别报错. Error:%@",err);
		return NO;
	}
    
    // Set our session to active...
    if ([[UIDevice currentDevice].systemVersion floatValue] < 8.0f) {
        if (![audioSession setActive:YES error:&err]) {
            LogError(kErrorMedia, @"设置音频会话激活状态报错. Error:%@",err);
            return NO;
        }
    }
    [self changeRoute:desiredAudioRoute];
    
	// Display our current route...
    self.currentSetRoute = self.audioRoute;
	return YES;
}

- (BOOL)firstDetectAvailableDevices
{
	// called on startup to initialize the devices that are available...
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *err = nil;
    
	// close down our current session...
	[audioSession setActive:NO error:nil];
    
    // start a new audio session. Without activation, the default route will always be (inputs: null, outputs: Speaker)
    [audioSession setActive:YES error:nil];
    
    if ( [audioSession respondsToSelector:@selector(setMode:error:) ])
    {
        [audioSession setMode:(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1
                               ? AVAudioSessionModeVideoChat
                               : AVAudioSessionModeVoiceChat)
                        error:&err];
    }
    else
    {
        uint32_t voiceChat = kAudioSessionMode_VoiceChat;
        AudioSessionSetProperty(kAudioSessionProperty_Mode, sizeof(voiceChat), &voiceChat);
    }
    
	// Open a session and see what our default is...
	if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&err]) {
        LogError(kErrorMedia, @"设置音频会话类别报错. Error:%@",err);
		return NO;
	}
    
    [self detectAvailableDevices];
    
	return YES;
}

- (void)detectAvailableDevices
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    // Check for a wired headset...
    AVAudioSessionRouteDescription *currentRoute = [audioSession currentRoute];
    for (AVAudioSessionPortDescription *output in currentRoute.outputs) {
        if ([[output portType] isEqualToString:AVAudioSessionPortHeadphones]) {
            self.headsetDeviceAvailable = YES;
        } else if ([self isBluetoothDevice:[output portType]]) {
            self.bluetoothDeviceAvailable = YES;
        }
    }
    // In case both headphones and bluetooth are connected, detect bluetooth by inputs
    // Condition: iOS7 and Bluetooth input available
    if ([audioSession respondsToSelector:@selector(availableInputs)]) {
        for (AVAudioSessionPortDescription *input in [audioSession availableInputs]){
            if ([self isBluetoothDevice:[input portType]]){
                self.bluetoothDeviceAvailable = YES;
                break;
            }
        }
    }
}

- (void)currentRouteChanged:(NSNotification *)notification
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSInteger changeReason = [[notification.userInfo objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    AVAudioSessionRouteDescription *oldRoute = [notification.userInfo objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    NSString *oldOutput = [[oldRoute.outputs objectAtIndex:0] portType];
    AVAudioSessionRouteDescription *newRoute = [audioSession currentRoute];
    NSString *newOutput = [[newRoute.outputs objectAtIndex:0] portType];
    switch (changeReason) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        {
            if ([self isBluetoothDevice:newOutput]) {
                self.bluetoothDeviceAvailable = YES;
            } else if ([newOutput isEqualToString:AVAudioSessionPortHeadphones]) {
                self.headsetDeviceAvailable = YES;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionNewDeviceAvailable object:self userInfo:notification.userInfo];
        }
            break;
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        {
            if ([oldOutput isEqualToString:AVAudioSessionPortHeadphones]) {
                
                self.headsetDeviceAvailable = NO;
                // Special Scenario:
                // when headphones are plugged in before the call and plugged out during the call
                // route will change to {input: MicrophoneBuiltIn, output: Receiver}
                // manually refresh session and support all devices again.
//                [audioSession setActive:NO error:nil];
//                [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
//                [audioSession setMode:AVAudioSessionModeVoiceChat error:nil];
//                [audioSession setActive:YES error:nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionRouteChangeNotification object:self userInfo:notification.userInfo];
            } else if ([self isBluetoothDevice:oldOutput]) {
                
                BOOL showBluetooth = NO;
                // Additional checking for iOS7 devices (more accurate)
                // when multiple blutooth devices connected, one is no longer available does not mean no bluetooth available
                if ([audioSession respondsToSelector:@selector(availableInputs)]) {
                    NSArray *inputs = [audioSession availableInputs];
                    for (AVAudioSessionPortDescription *input in inputs){
                        if ([self isBluetoothDevice:[input portType]]){
                            showBluetooth = YES;
                            break;
                        }
                    }
                }
                if (!showBluetooth) {
                    self.bluetoothDeviceAvailable = NO;
                }
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionOldDeviceUnavailable object:self userInfo:notification.userInfo];
        }
            break;
            
        case AVAudioSessionRouteChangeReasonOverride:
        {
            if ([self isBluetoothDevice:oldOutput]) {
                if ([audioSession respondsToSelector:@selector(availableInputs)]) {
                    BOOL showBluetooth = NO;
                    NSArray *inputs = [audioSession availableInputs];
                    for (AVAudioSessionPortDescription *input in inputs){
                        if ([self isBluetoothDevice:[input portType]]){
                            showBluetooth = YES;
                            break;
                        }
                    }
                    if (!showBluetooth) {
                        self.bluetoothDeviceAvailable = NO;
                    }
                } else if ([newOutput isEqualToString:AVAudioSessionPortBuiltInReceiver]) {
                    self.bluetoothDeviceAvailable = NO;
                }
            }
        }
            break;
            
        case AVAudioSessionRouteChangeReasonCategoryChange:
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
        {
            if ([self isBluetoothDevice:newOutput]) {
                self.bluetoothDeviceAvailable = YES;
            } else if ([newOutput isEqualToString:AVAudioSessionPortHeadphones]) {
                self.headsetDeviceAvailable = YES;
            }
            
            if ( self.currentSetRoute && ![self.currentSetRoute isEqualToString:self.audioRoute] ) {
                if ( NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 ) {
                    if ( changeReason == AVAudioSessionRouteChangeReasonRouteConfigurationChange ) {
                        self.audioRoute = self.currentSetRoute;
                    }
                } else {
                    self.audioRoute = self.currentSetRoute;
                }
            }
        }
            break;
            
        default:
            break;
    }
    
    if ( changeReason != AVAudioSessionRouteChangeReasonRouteConfigurationChange) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionDeviceChangedNotification
                                                            object:self
                                                          userInfo:@{ kAudioSessionDeviceChangedNotification:@(kAudioSessionDeviceType_Headset) }];
    }
}

- (void)audioSessionInterruption:(NSNotification *)notification
{
    NSUInteger interruptionType = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch ( interruptionType )
    {
        case AVAudioSessionInterruptionTypeBegan:
        {
            
        }
            break;
            
        case AVAudioSessionInterruptionTypeEnded:
        {
            
        }
            break;
            
        default:
            break;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionInterruptionNotification object:self userInfo:notification.userInfo];
}

- (BOOL)isBluetoothDevice:(NSString*)portType {
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        return ([portType isEqualToString:AVAudioSessionPortBluetoothA2DP]
                || [portType isEqualToString:AVAudioSessionPortBluetoothHFP]
                || [portType isEqualToString:AVAudioSessionPortBluetoothLE]);
    } else {
        return ([portType isEqualToString:AVAudioSessionPortBluetoothA2DP]
                || [portType isEqualToString:AVAudioSessionPortBluetoothHFP]);
    }
}

- (void)proximityStateChanged:(NSNotification *)notification
{
    if ([UIDevice currentDevice].proximityState)
    {
        _currentDeviceRoute = self.audioRoute;
        _currentMode = mMode;
        if (_currentDeviceRoute != kAudioSessionManagerDevice_Bluetooth
            && _currentDeviceRoute != kAudioSessionManagerDevice_Headset
            && _currentDeviceRoute != kAudioSessionManagerDevice_Phone) {
            mMode = kAudioSessionManagerMode_Record;
            self.audioRoute = kAudioSessionManagerDevice_Bluetooth;
        }
    }
    else
    {
        mMode = _currentMode;
        self.audioRoute = _currentDeviceRoute;
    }
}

#pragma mark public methods

- (void)start {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self firstDetectAvailableDevices];
    });
    
    if ( !_isInitialized ) {
        _isInitialized = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(currentRouteChanged:)
                                                     name:AVAudioSessionRouteChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionInterruption:)
                                                     name:AVAudioSessionInterruptionNotification object:nil];
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(proximityStateChanged:)
//                                                     name:UIDeviceProximityStateDidChangeNotification
//                                                   object:nil];
    }
}

- (void)stop {
    _isInitialized = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setActive:(BOOL)value
{
	[[AVAudioSession sharedInstance] setActive:value error:nil];
}

- (void)setAudioRouteWithSpeaker:(BOOL)speaker
{
    if (mHeadsetDeviceAvailable || mBluetoothDeviceAvailable) {
        speaker = NO;
    }

    NSError *err = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL res = NO;
    if (speaker) {
        mMode = kAudioSessionManagerMode_Playback;

        if (![audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:&err]) {
            LogError(kErrorMedia, @"设置音频会话类别报错. Speaker:%d. Error:%@",speaker, err);
            return;
        }
        
        [self setAudioRoute:kAudioSessionManagerDevice_Speaker];
        /*
        if (![[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&err]) {
            LogError(kErrorMedia, @"Unable to overrideOutputAudioPort. Speaker:%d. Error:%@",speaker, err);
            return;
        };
         */
    } else {
        mMode = kAudioSessionManagerMode_Record;

        if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&err]) {
            LogError(kErrorMedia, @"设置音频会话类别报错. Speaker:%d. Error:%@",speaker, err);
            return;
        }

        // [self setAudioRoute:kAudioSessionManagerDevice_Bluetooth];
        if ( [audioSession respondsToSelector:@selector(overrideOutputAudioPort:error:)] ) {
            // replace AudiosessionSetProperty (deprecated from iOS7) with AVAudioSession overrideOutputAudioPort
            if (![[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&err]) {
                LogError(kErrorMedia, @"Unable to overrideOutputAudioPort. Speaker:%d. Error:%@",speaker, err);
                return;
            }
        } else {
            UInt32 doChangeDefaultRoute = 0;
            AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(doChangeDefaultRoute), &doChangeDefaultRoute);
        }
    }

    // Display our current route...
}

#pragma mark public methods/properties

- (BOOL)changeMode:(NSString *)value
{
	if (mMode == value)
		return YES;
    
	mMode = value;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *err = nil;
    
	// close down our current session...
	[audioSession setActive:NO error:nil];
    
    if ((mMode == kAudioSessionManagerMode_Record) && !audioSession.inputAvailable) {
		LogError(kErrorMedia, @"设备无录音权限/不支持录音");
		return NO;
    }
    
    /*
     * Need to always use AVAudioSessionCategoryPlayAndRecord to redirect output audio per
     * the "Audio Session Programming Guide", so we only use AVAudioSessionCategoryPlayback when
     * !inputIsAvailable - which should only apply to iPod Touches without external mics.
     */
    NSString *audioCat = (mMode == kAudioSessionManagerMode_Playback) ? AVAudioSessionCategoryPlayback : AVAudioSessionCategoryPlayAndRecord;
	if (![audioSession setCategory:audioCat withOptions:((self.audioRoute == kAudioSessionManagerDevice_Bluetooth) ? AVAudioSessionCategoryOptionAllowBluetooth : 0) error:&err]) {
        LogError(kErrorMedia, @"设置音频会话类别报错. Error:%@",err);
		return NO;
	}
    
    // Set our session to active...
	if (![audioSession setActive:YES error:&err]) {
        LogError(kErrorMedia, @"设置音频会话激活状态报错. Error:%@",err);
		return NO;
	}

    return YES;
//	return [self configureAudioSessionWithDesiredAudioRoute:kAudioSessionManagerDevice_Bluetooth];
}

- (BOOL)changeRoute:(NSString *)desiredAudioRoute
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *err;
    
    if ( desiredAudioRoute == kAudioSessionManagerDevice_Speaker ) { // 扬声器
        if ( [audioSession respondsToSelector:@selector(overrideOutputAudioPort:error:)] ) {
            // replace AudiosessionSetProperty (deprecated from iOS7) with AVAudioSession overrideOutputAudioPort
            [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&err];
        } else {
            UInt32 doChangeDefaultRoute = 1;
            AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(doChangeDefaultRoute), &doChangeDefaultRoute);
        }
        
        //
        [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionDeviceChangedNotification
                                                            object:self
                                                          userInfo:@{ kAudioSessionDeviceChangedNotification:@(kAudioSessionDeviceType_Speaker) }];
	}
    else if ( desiredAudioRoute == kAudioSessionManagerDevice_Headset || desiredAudioRoute == kAudioSessionManagerDevice_Phone ) { // 耳机
        if ( [audioSession respondsToSelector:@selector(overrideOutputAudioPort:error:)] ) {
            // replace AudiosessionSetProperty (deprecated from iOS7) with AVAudioSession overrideOutputAudioPort
            [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&err];
        } else {
            UInt32 doChangeDefaultRoute = 0;
            AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(doChangeDefaultRoute), &doChangeDefaultRoute);
        }
        
        //
        [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionDeviceChangedNotification
                                                            object:self
                                                          userInfo:@{ kAudioSessionDeviceChangedNotification:@(kAudioSessionDeviceType_Headset) }];
    }
    else if ( desiredAudioRoute == kAudioSessionManagerDevice_Bluetooth ) { // 蓝牙
        if ( self.bluetoothDeviceAvailable ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionDeviceChangedNotification
                                                                object:self
                                                              userInfo:@{ kAudioSessionDeviceChangedNotification:@(kAudioSessionDeviceType_Bluetooth) }];
        }
    }
    return YES;
}

- (BOOL)changeCategoryOptions:(NSString *)category withOptions:(AVAudioSessionCategoryOptions)options
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if ( ![audioSession.category isEqualToString:category] ) {
        NSError *err = nil;
        // Open a session and see what our default is...
        if (![audioSession setCategory:category withOptions:options error:&err]) {
            LogError(kErrorMedia, @"设置音频会话类别报错. Error:%@",err);
            return NO;
        }
    }
    return YES;
}

- (NSString *)audioRoute
{
	AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    NSString *output = [currentRoute.outputs.firstObject portType];
    if ([output isEqualToString:AVAudioSessionPortBuiltInReceiver]) { // 听筒
        return kAudioSessionManagerDevice_Phone;
    } else if ([output isEqualToString:AVAudioSessionPortBuiltInSpeaker]) { // 扬声器
        return kAudioSessionManagerDevice_Speaker;
    } else if ([output isEqualToString:AVAudioSessionPortHeadphones]) { // 耳机
        return kAudioSessionManagerDevice_Headset;
    } else if ([self isBluetoothDevice:output]) { // 蓝牙耳机
        return kAudioSessionManagerDevice_Bluetooth;
    } else {
        return @"Unknown Device";
    }
}

- (void)setBluetoothDeviceAvailable:(BOOL)value
{
	if (mBluetoothDeviceAvailable == value) {
		return;
    }
    
	mBluetoothDeviceAvailable = value;
    
	self.availableAudioDevices = nil;
}

- (void)setHeadsetDeviceAvailable:(BOOL)value
{
	if (mHeadsetDeviceAvailable == value) {
		return;
    }
    
	mHeadsetDeviceAvailable = value;
    
	self.availableAudioDevices = nil;
}

- (void)setAudioRoute:(NSString *)audioRoute
{
	if ([self audioRoute] == audioRoute) {
		return;
    }
    
	[self configureAudioSessionWithDesiredAudioRoute:audioRoute];
}

- (void)setDefaultToSpeaker:(BOOL)value
{
    if (mDefaultToSpeaker == value) {
        return;
    }
    
    mDefaultToSpeaker = value;
    
    [self setAudioRouteWithSpeaker:mDefaultToSpeaker];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kAppDefaultToSpeakerChangeNotification object:self];
}

- (BOOL)phoneDeviceAvailable
{
    NSString *hardware = [UIDevice currentDevice].model;
    if ( [hardware rangeOfString:@"iPhone"].length > 0 )
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)speakerDeviceAvailable
{
	return YES;
}

- (NSArray *)availableAudioDevices
{
	if (!mAvailableAudioDevices) {
		NSMutableArray *devices = [[NSMutableArray alloc] initWithCapacity:4];
        
		if (self.bluetoothDeviceAvailable)
			[devices addObject:kAudioSessionManagerDevice_Bluetooth];
        
		if (self.headsetDeviceAvailable)
			[devices addObject:kAudioSessionManagerDevice_Headset];
        
		if (self.speakerDeviceAvailable)
			[devices addObject:kAudioSessionManagerDevice_Speaker];
        
		if (self.phoneDeviceAvailable)
			[devices addObject:kAudioSessionManagerDevice_Phone];
        
		self.availableAudioDevices = devices;
	}
    
	return mAvailableAudioDevices;
}

#pragma mark - UIApplication EnterBackground/Screen lock notify

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#if !kZhaoHu
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateInactive)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kAppScreenLockedNotification object:nil];
    }
    else if (state == UIApplicationStateBackground)
    {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisplayStatusLocked"])
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kAppScreenLockedNotification object:nil];
//            LogDebug(@"Sent to background by home button/switching to other app");
        }
//        else
//        {
//            [[NSNotificationCenter defaultCenter] postNotificationName:kAppScreenLockedNotification object:nil];
//        }
    }
#endif
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"kDisplayStatusLocked"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self detectAvailableDevices];
}

@end
