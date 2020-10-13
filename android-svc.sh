#!/bin/bash

#ANDROID_SVC_LIB_BEGIN
if [ -f "${PREFIX}/lib/android-svc-lib.sh" ]; then
    source "${PREFIX}/lib/android-svc-lib.sh"
elif [ -f "./android-svc-lib.sh" ]; then
    source ./android-svc-lib.sh
else
    >&2 echo "ERROR: 'android-svc-lib.sh' is missing!"
    exit 1
fi
#ANDROID_SVC_LIB_END

if [ "$1" == "help" ] || [ "$1" == "--help" ]; then
    echo "USAGE:"
    echo ""
    echo "android-svc [options] download"
    echo "Description: Enable offline usage by downloading required Android source code files for the current device."
    echo "Example: android-svc download"
    echo ""
    echo "android-svc [options] call 'SERVICE_PACKAGE_NAME.METHOD_NAME(arguments)'"
    echo "Description: Call a service method."
    echo "Example: android-svc call 'com.android.internal.telephony.ITelephony.dial(\"555-0199\")'"
    echo ""
    echo "android-svc [options] convert 'SERVICE_PACKAGE_NAME.METHOD_NAME(arguments)'"
    echo "Description: Convert a service method call to a bash command. THE RESULTING COMMAND WILL ONLY WORK FOR THE EXACT ANDROID VERSION OF YOUR DEVICE!"
    echo "Example: android-svc convert 'com.android.internal.telephony.ITelephony.dial(\"555-0199\")'"
    echo ""
    echo "android-svc [options] list-packages"
    echo "Description: List all service package names."
    echo "Example: android-svc list-packages"
    echo ""
    echo "android-svc [options] list-methods SERVICE_PACKAGE_NAME"
    echo "Description: List all methods for a service package."
    echo "Example: android-svc list-methods android.content.pm.IPackageManager"
    echo ""
    echo "android-svc [options] method-signature SERVICE_PACKAGE_NAME.METHOD_NAME"
    echo "Description: Get method-signature for a specific method."
    echo "Example: android-svc method-signature android.media.IAudioService.isMasterMute"
    echo ""
    echo "Supported options are --adb or --adb=<device-id>"
    echo "(You only need this in order to use this from a Linux machine via ADB.)"
    echo ""
    echo "android-svc help"
    echo "Description: Print this message."
    echo "Example: android-svc help"
    exit 0
elif [ "$1" == "version" ] || [ "$1" == "--version" ]; then
    echo "$g_ANDROID_SVC_LIB_VERSION"
    exit 0
elif [[ "$1" == "--adb="* ]]; then
    SetShellType "adb"
    SetAdbDevice "$(echo "$1" | cut -d'=' -f2)"
    command="$2"
    commandParam1="$3"
elif [ "$1" == "--adb" ]; then
    SetShellType "adb"
    command="$2"
    commandParam1="$3"
else
    command="$1"
    commandParam1="$2"
fi

Init

if [ "$command" == "call" ]; then
    CallServiceMethod "$commandParam1"
elif [ "$command" == "convert" ]; then
    ConvertServiceCallToShellCommand "$commandParam1"
elif [ "$command" == "list-packages" ]; then
    GetServicePackageNames
elif [ "$command" == "list-methods" ]; then
    if [[ $commandParam1 == *"."* ]]; then # A service package name was given
        servicePackageName="$commandParam1"
    else # A service code name was given
        servicePackageName="$(GetServicePackageName "$l_serviceCodeName")"
    fi
    GetMethodSignaturesForPackage "${servicePackageName}"
elif [ "$command" == "method-signature" ]; then
    methodName=$(echo "$commandParam1" | rev | cut -d'.' -f 1 | rev)
    servicePackageName=$(echo "$commandParam1" | rev | cut -d"." -f2-  | rev)
    GetMethodSignature "${servicePackageName}" "${methodName}"
elif [ "$command" == "download" ]; then
    DownloadSourceFiles "${g_aidlFileList}" "${g_aidlFileCache}"
else
    Exit 1 "Command not found!"
fi