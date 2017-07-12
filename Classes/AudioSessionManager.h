//
//  AudioSessionManager.h
//
//  This module routes audio output depending on device availability using the
//  following priorities: bluetooth, wired headset, speaker.
//
//  It also notifies interested listeners of audio change events (optional).
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

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern NSString *kAudioSessionManagerMode_Record;
extern NSString *kAudioSessionManagerMode_Playback;

extern NSString *kAudioSessionManagerDevice_Headset;
extern NSString *kAudioSessionManagerDevice_Bluetooth;
extern NSString *kAudioSessionManagerDevice_Phone;
extern NSString *kAudioSessionManagerDevice_Speaker;

// notification
extern NSString *kAudioSessionRouteChangeNotification;
extern NSString *kAudioSessionInterruptionNotification;
extern NSString *kAudioSessionDeviceChangedNotification;
extern NSString *kAudioSessionBluetoothDeviceAvailableNotification;
extern NSString *kAudioSessionOldDeviceUnavailable;
extern NSString *kAudioSessionNewDeviceAvailable;
extern NSString *kProximityStateDidChangeNotification;
extern NSString *kAppDefaultToSpeakerChangeNotification;

typedef NS_ENUM(NSUInteger, kAudioSessionDeviceType)
{
    kAudioSessionDeviceType_Headset,
    kAudioSessionDeviceType_Bluetooth,
    kAudioSessionDeviceType_Speaker,
};

@interface AudioSessionManager : NSObject

/**
 The current audio route.
 
 Valid values at this time are:
 - kAudioSessionManagerDevice_Bluetooth
 - kAudioSessionManagerDevice_Headset
 - kAudioSessionManagerDevice_Phone
 - kAudioSessionManagerDevice_Speaker
 */
@property (nonatomic, assign)   NSString  *audioRoute;

/**
 Just for application settings configure.
 */
@property (nonatomic, assign)   BOOL       defaultToSpeaker;

/**
 Returns YES if a wired headset is available.
 */
@property (nonatomic, readonly) BOOL       headsetDeviceAvailable;

/**
 Returns YES if a bluetooth device is available.
 */
@property (nonatomic, readonly) BOOL       bluetoothDeviceAvailable;

/**
 Returns YES if the device's earpiece is available (always true for now).
 */
@property (nonatomic, readonly) BOOL       phoneDeviceAvailable;

/**
 Returns YES if the device's speakerphone is available (always true for now).
 */
@property (nonatomic, readonly) BOOL       speakerDeviceAvailable;

@property (nonatomic, strong) NSString      *currentSetRoute;

/**
 Returns a list of the available audio devices. Valid values at this time are:
 - kAudioSessionManagerDevice_Bluetooth
 - kAudioSessionManagerDevice_Headset
 - kAudioSessionManagerDevice_Phone
 - kAudioSessionManagerDevice_Speaker
 */
@property (nonatomic, readonly) NSArray  *availableAudioDevices;

///**
// Returns the AudioSessionManager singleton, creating it if it does not already exist.
// */
+ (AudioSessionManager *)sharedAudioSessionManager;
//+ (AudioSessionManager *)sharedInstance;

/**
 Switch between recording and playback modes. Returns NO if the mode change failed.
 
 @param value must be kAudioSessionManagerMode_Record or kAudioSessionManagerMode_Playback
 */
- (BOOL)changeMode:(NSString *)value;

- (BOOL)changeRoute:(NSString *)desiredAudioRoute;

- (BOOL)changeCategoryOptions:(NSString *)category withOptions:(AVAudioSessionCategoryOptions)options;

/**
 Initialize by detecting all available devices and selecting one based on the following priority:
 - bluetooth
 - headset
 - speaker
 */
- (void)start;

/**
 Stop detecting all available devices and selecting one based on the following priority:
 - bluetooth
 - headset
 - speaker
 */
- (void)stop;

/**
 set AVAudioSession active or inactive
 */
- (void)setActive:(BOOL)value;

/**
 1. when headset and bluetooth device is available, use headset and bluetooth
 2. when headset and bluetooth device is unavailable: use Speaker if speaker is YES, otherwise use Phone(Receiver)
 */
- (void)setAudioRouteWithSpeaker:(BOOL)speaker;

@end
