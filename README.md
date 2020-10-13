# Commandline wrapper for Android's serivce utility

## About
`android-svc` aims at making it easier to call service methods over ADB or using a terminal emulator on your Android device directly.  
Using Android's built-in `service` utility forces you to manually go through the Android source code and its AIDL files.  
You can for example simply call  
``` Bash
android-svc call 'android.content.pm.IPackageManager.getInstallerPackageName("com.nononsenseapps.feeder");'
#or
android-svc call 'package.getInstallerPackageName("com.nononsenseapps.feeder");'
```
instead of
``` Bash
service call package 65 s16 'com.nononsenseapps.feeder'
```
which would have required you to understand how to get values like `65` or `s16` and write different code for every device and Android version you want to use it on.  

## Demo
![demo](./demo.gif)

## Features

- [x] Call service methods
- [x] List available service packages
- [x] List available methods for service packages
- [x] Show method signatures (including data types for arguments and return values)
- [x] Convert given service method calls into a bash commands
- [x] Offline mode
- [x] Works over ADB (from Linux host)
- [x] Works directly on the phone (requires Termux)
- [x] Supports the following data types: void, boolean, char, int, long, float, double, String

## Limitations

- Requires root
- I need help decoding/encoding all complex datatypes like arrays, Lists, ParceledListSlice etc.
- String are decoded ignoring the first 8 bits of every char. This works fine as long as only UTF-8 characters are being used. When a string contains a UTF-16 character the decoded output will be incorrect. Any help properly decoding utf-16 hex code in bash would be appreciated.
- String decoding is slow. Any help improving the performance would be apperciated.

## Disclaimer
**Use at own risk!**
- May call incorrect service methods on ROMs that have added/removed methods to/from the aidl files as they appear in AOSP. I recommend using LineageOS to reduce that risk. If you use another open source ROM, we can probably add support for detecting that by scanning its source code, just like I've done it for LineageOS.
- Only tested on amd64 based devices.

## How to install (in Termux)
- Download the deb package from the [latest release](https://github.com/T-vK/android-svc/releases).
- Install it using `apt install path/to/android-svc_x.x.x_all.deb` (replaceing x.x.x with the actual version)

## How to install (in Linux)
- Download the standalone executable from the [latest release](https://github.com/T-vK/android-svc/releases). (It's the `android-svc` file.)
- Make it executable by running `chmod +x ./android-svc`.
- Optional: Add the containing folder to your PATH or copy android-svc into a folder that's in PATH already.
  Otherwise you'll have to use it like `path/to/android-svc help` instead of `android-svc help`

Alternatively you can of course clone the repo with git and execute android-svc.sh directly.

## How to build
If you want to build it yourself instead of using a release, you can do it like this:

```
git clone https://github.com/T-vK/android-svc.git
cd ./android-svc
./build.sh
```

This will create a folder called 'build' in which you'll find the standalone executable and the deb package for Termux.


## How to use

Run `android-svc help` to get the following help message:
``` Bash
android-svc [options] download
Description: Enable offline usage by downloading required Android source code files for the current device.
Example: android-svc download

android-svc [options] call 'SERVICE_PACKAGE_NAME.METHOD_NAME(arguments)'
Description: Call a service method.
Example: android-svc call 'com.android.internal.telephony.ITelephony.dial("555-0199")'

android-svc [options] convert 'SERVICE_PACKAGE_NAME.METHOD_NAME(arguments)'
Description: Convert a service method call to a bash command. THE RESULTING COMMAND WILL ONLY WORK FOR THE EXACT ANDROID VERSION OF YOUR DEVICE!
Example: android-svc convert 'com.android.internal.telephony.ITelephony.dial("555-0199")'

android-svc [options] list-packages
Description: List all service package names.
Example: android-svc list-packages

android-svc [options] list-methods SERVICE_PACKAGE_NAME
Description: List all methods for a service package.
Example: android-svc list-methods android.content.pm.IPackageManager

android-svc [options] method-signature SERVICE_PACKAGE_NAME.METHOD_NAME
Description: Get method-signature for a specific method.
Example: android-svc method-signature android.media.IAudioService.isMasterMute

Supported options are --adb or --adb=<device-id>
(You only need this in order to use this from a Linux machine via ADB.)

android-svc help
Description: Print this message.
Example: android-svc help
```

## Examples with example output:

``` Bash
# Example 1 (Enables offline usage):
$ android-svc download
Downloading 'core/java/android/accessibilityservice/IAccessibilityServiceClient.aidl'
Downloading 'core/java/android/accessibilityservice/IAccessibilityServiceConnection.aidl'
Downloading 'core/java/android/accounts/IAccountAuthenticator.aidl'
Downloading 'core/java/android/accounts/IAccountAuthenticatorResponse.aidl'
Downloading 'core/java/android/accounts/IAccountManager.aidl'
Downloading 'core/java/android/accounts/IAccountManagerResponse.aidl'
...



# Example 2 (Find out which App installed another app):
$ android-svc call 'android.content.pm.IPackageManager.getInstallerPackageName("com.nononsenseapps.feeder");'
org.fdroid.fdroid.privileged



# Example 3 (Find out if the master volume is muted):
$ android-svc call 'android.media.IAudioService.isMasterMute();'
false



# Example 4 (Dial a given phone number):
$ android-svc call 'com.android.internal.telephony.ITelephony.dial("555-0199")'



# Example 5 (Convert the given package-method-call into a shell command (which only works for the exact same Android version):
$ android-svc convert 'android.content.pm.IPackageManager.getInstallerPackageName("com.nononsenseapps.feeder");'
service call package 65 s16 'com.nononsenseapps.feeder'



# Example 6 (Get info about arguments and return data types about a given method from a given package):
$ android-svc info android.content.pm.IPackageManager.getInstallerPackageName
String getInstallerPackageName(in String packageName);



# Example 7 (List all methods available for a given package):
$ android-svc methods 'android.media.IAudioService'
int trackPlayer(in PlayerBase.PlayerIdCard pic);
oneway void playerAttributes(in int piid, in AudioAttributes attr);
oneway void playerEvent(in int piid, in int event);
oneway void releasePlayer(in int piid);
oneway void adjustSuggestedStreamVolume(int direction, int suggestedStreamType, int flags,String callingPackage, String caller);
void adjustStreamVolume(int streamType, int direction, int flags, String callingPackage);
void setStreamVolume(int streamType, int index, int flags, String callingPackage);
boolean isStreamMute(int streamType);
void forceRemoteSubmixFullVolume(boolean startForcing, IBinder cb);
boolean isMasterMute();
void setMasterMute(boolean mute, int flags, String callingPackage, int userId);
int getStreamVolume(int streamType);
int getStreamMinVolume(int streamType);
int getStreamMaxVolume(int streamType);
int getLastAudibleStreamVolume(int streamType);
void setMicrophoneMute(boolean on, String callingPackage, int userId);
void setRingerModeExternal(int ringerMode, String caller);
void setRingerModeInternal(int ringerMode, String caller);
int getRingerModeExternal();
int getRingerModeInternal();
boolean isValidRingerMode(int ringerMode);
void setVibrateSetting(int vibrateType, int vibrateSetting);
int getVibrateSetting(int vibrateType);
boolean shouldVibrate(int vibrateType);
void setMode(int mode, IBinder cb, String callingPackage);
int getMode();
oneway void playSoundEffect(int effectType);
oneway void playSoundEffectVolume(int effectType, float volume);
boolean loadSoundEffects();
oneway void unloadSoundEffects();
oneway void reloadAudioSettings();
oneway void avrcpSupportsAbsoluteVolume(String address, boolean support);
void setSpeakerphoneOn(boolean on);
boolean isSpeakerphoneOn();
void setBluetoothScoOn(boolean on);
void setBluetoothA2dpOn(boolean on);
boolean isBluetoothA2dpOn();
int requestAudioFocus(in AudioAttributes aa, int durationHint, IBinder cb,IAudioFocusDispatcher fd, String clientId, String callingPackageName, int flags,IAudioPolicyCallback pcb, int sdk);
int abandonAudioFocus(IAudioFocusDispatcher fd, String clientId, in AudioAttributes aa,in String callingPackageName);
void unregisterAudioFocusClient(String clientId);
int getCurrentAudioFocus();
void startBluetoothSco(IBinder cb, int targetSdkVersion);
void startBluetoothScoVirtualCall(IBinder cb);
void stopBluetoothSco(IBinder cb);
void forceVolumeControlStream(int streamType, IBinder cb);
void setRingtonePlayer(IRingtonePlayer player);
IRingtonePlayer getRingtonePlayer();
int getUiSoundsStreamType();
void setWiredDeviceConnectionState(int type, int state, String address, String name,String caller);
int setBluetoothA2dpDeviceConnectionState(in BluetoothDevice device, int state, int profile);
void handleBluetoothA2dpDeviceConfigChange(in BluetoothDevice device);
AudioRoutesInfo startWatchingRoutes(in IAudioRoutesObserver observer);
boolean isCameraSoundForced();
void setVolumeController(in IVolumeController controller);
void notifyVolumeControllerVisible(in IVolumeController controller, boolean visible);
boolean isStreamAffectedByRingerMode(int streamType);
boolean isStreamAffectedByMute(int streamType);
void disableSafeMediaVolume(String callingPackage);
int setHdmiSystemAudioSupported(boolean on);
boolean isHdmiSystemAudioSupported();
String registerAudioPolicy(in AudioPolicyConfig policyConfig,in IAudioPolicyCallback pcb, boolean hasFocusListener, boolean isFocusPolicy,boolean isVolumeController);
oneway void unregisterAudioPolicyAsync(in IAudioPolicyCallback pcb);
int addMixForPolicy(in AudioPolicyConfig policyConfig, in IAudioPolicyCallback pcb);
int removeMixForPolicy(in AudioPolicyConfig policyConfig, in IAudioPolicyCallback pcb);
int setFocusPropertiesForPolicy(int duckingBehavior, in IAudioPolicyCallback pcb);
void setVolumePolicy(in VolumePolicy policy);
void registerRecordingCallback(in IRecordingConfigDispatcher rcdb);
oneway void unregisterRecordingCallback(in IRecordingConfigDispatcher rcdb);
List<AudioRecordingConfiguration> getActiveRecordingConfigurations();
void registerPlaybackCallback(in IPlaybackConfigDispatcher pcdb);
oneway void unregisterPlaybackCallback(in IPlaybackConfigDispatcher pcdb);
List<AudioPlaybackConfiguration> getActivePlaybackConfigurations();
void disableRingtoneSync(in int userId);
int getFocusRampTimeMs(in int focusGain, in AudioAttributes attr);
int dispatchFocusChange(in AudioFocusInfo afi, in int focusChange,in IAudioPolicyCallback pcb);
oneway void playerHasOpPlayAudio(in int piid, in boolean hasOpPlayAudio);
int setBluetoothHearingAidDeviceConnectionState(in BluetoothDevice device,int state, boolean suppressNoisyIntent, int musicDevice);
int setBluetoothA2dpDeviceConnectionStateSuppressNoisyIntent(in BluetoothDevice device,int state, int profile, boolean suppressNoisyIntent, int a2dpVolume);
oneway void setFocusRequestResultFromExtPolicy(in AudioFocusInfo afi, int requestResult,in IAudioPolicyCallback pcb);
void registerAudioServerStateDispatcher(IAudioServerStateDispatcher asd);
oneway void unregisterAudioServerStateDispatcher(IAudioServerStateDispatcher asd);
boolean isAudioServerRunning();
```

## Interesting code to further inspect in order to find the aidl files for packages that have missing data in `serivce list`
(This is just a note for me)
 - https://github.com/aosp-mirror/platform_frameworks_base/blob/a4ddee215e41ea232340c14ef92d6e9f290e5174/core/java/android/content/Context.java#L4056
 - https://github.com/aosp-mirror/platform_frameworks_base/blob/master/media/java/android/media/IAudioService.aidl
 - https://android.googlesource.com/platform/frameworks/native/+/android-8.0.0_r36/services/audiomanager/IAudioManager.cpp
 - https://android.googlesource.com/platform/frameworks/native/+/android-8.0.0_r36/include/audiomanager/IAudioManager.h
 - https://github.com/aosp-mirror/platform_frameworks_base/blob/a4ddee215e41ea232340c14ef92d6e9f290e5174/packages/SystemUI/src/com/android/systemui/media/RingtonePlayer.java#L66

## Credits
Credits to @ktnr74 for his [get_android_service_call_numbers.sh](https://gist.github.com/ktnr74/ac6b34f11d1e781db089#file-get_android_service_call_numbers-sh)
Credits to @bashenk for [his fork](https://gist.github.com/bashenk/b538ce0a60efe6a9c3b446683744d598#file-get_android_service_call_numbers-sh) of ktnr74's work, which adds some improvements.

`android-svc` is based on that work, although most of the code has been rewritten and a lot of new features and fixes have been implemented.
