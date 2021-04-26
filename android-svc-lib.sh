export g_ANDROID_SVC_LIB_VERSION=0.2.1
export g_repoUrl=""
export g_aidlFileList=""
export g_shellType=""
export g_adbSerial=""
export g_aidlFileCache="./.android-svc-cache"

export g_blue=$(printf '%s\n' '\033[0;34m' | sed -e 's/[\/&]/\\&/g')
export g_red=$(printf '%s\n' '\033[0;31m' | sed -e 's/[\/&]/\\&/g')
export g_green=$(printf '%s\n' '\033[0;32m' | sed -e 's/[\/&]/\\&/g')
export g_yellow=$(printf '%s\n' '\033[0;33m' | sed -e 's/[\/&]/\\&/g')
export g_nc=$(printf '%s\n' '\033[0m' | sed -e 's/[\/&]/\\&/g') # no color

###
# init g_repoUrl value
# GLOBALS:
#  l_targetDir
#  g_repoUrl will be filled by this method, and contains an url from https://github.com/aosp-mirror/platform_frameworks_base repository
# RETURN:
#   nothing or exit the script with an error message
Init () {
    g_repoUrl="${1-}"
    if ! [ -n "$g_repoUrl" ]; then
        if [ -f "${l_targetDir}/REPO_URL" ]; then
            export g_repoUrl="$(cat "${l_targetDir}/REPO_URL")"
        else
            export g_repoUrl="$(GetSourceRepoUrl)"
        fi
    fi
    [ -n "$g_repoUrl" ] || Exit 1 "Android source code repository URL was not provided and could not automatically be retrieved in Init"

    export g_aidlFileList="$(GetServiceAidlFileNames)"
}

DownloadSourceFiles () {
    l_sourceFileList="${1-}"; l_targetDir="${2-}"
    [ -n "$l_sourceFileList" ] || Exit 1 "Source file list was not provided in DownloadSourceFiles"
    [ -n "$l_targetDir" ] || Exit 1 "Target directory was not provided in DownloadSourceFiles"
    [ -n "$g_repoUrl" ] || Exit 1 "Android source code repository URL was empty in DownloadSourceFiles (Did you call Init first?)"

    l_targetDir="${l_targetDir}/$(GetRomName)"

    while IFS= read -r aidlFile; do
        l_currentFile="${l_targetDir}/${aidlFile}"
        if ! [ -f "$l_currentFile" ]; then
            echo "Downloading '${aidlFile}'"
            mkdir -p "${l_currentFile%/*}"
            GetSourceFile "${aidlFile}" > "${l_currentFile}"
        else
            echo "Skipping '${aidlFile}' (already exists)"
        fi
    done <<< "$l_sourceFileList"
    echo "$g_repoUrl" > "${l_targetDir}/REPO_URL"
}

###
# call a service with argument on a device
# ARGUMENTS:
#  a call like 'com.android.internal.telephony.ITelephony.dial(\"555-0199\")'"
# RETURN:
#  converted call ready to be pass to adb shell
ConvertServiceCallToShellCommand () {
    l_serviceCall="${1-}"
    [ -n "$l_serviceCall" ] || Exit 1 "Service call not provided in CallServiceMethod"

    l_fullCallPath=$(echo "$l_serviceCall" | cut -d'(' -f1)
    l_methodName=$(echo "$l_fullCallPath" | rev | cut -d'.' -f 1 | rev)
    l_serviceCodeName=$(echo "$l_fullCallPath" | rev | cut -d"." -f2-  | rev)
    if [[ $l_serviceCodeName == *"."* ]]; then # A service package name was given
        l_servicePackageName="$l_serviceCodeName"
        l_serviceCodeName="$(GetServiceCodeName "$l_servicePackageName")"
    else # A service code name was given
        l_servicePackageName="$(GetServicePackageName "$l_serviceCodeName")"
    fi

    l_methodIndex="$(GetMethodIndex "${l_servicePackageName}" "${l_methodName}")"

    # Get data types for method parameters
    l_methodSignature="$(GetMethodSignature "$l_servicePackageName" "$l_methodName")"
    l_rawParamsDefiniton="$(echo "$l_methodSignature" | cut -d'(' -f2 | rev | cut -d')' -f2- | rev)"

    l_shellServiceCall="service call $l_serviceCodeName $l_methodIndex"

    if [ "$l_rawParamsDefiniton" != "" ]; then
        readarray -td, l_paramTypeArray <<<"$l_rawParamsDefiniton"; declare -p l_paramTypeArray > /dev/null
        for i in "${!l_paramTypeArray[@]}"; do
            l_paramTypeArray[i]=$(echo "${l_paramTypeArray[i]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | rev | cut -d' ' -f2- | rev)
            #echo "Data type for argument $i: ${paramTypeArray[i]}"
        done

        # Get user given method arguments
        l_rawArgs=$(echo "$l_serviceCall" | cut -d'(' -f2 | rev | cut -d")" -f2-  | rev)
        readarray -td, l_rawArgsArray <<<"$l_rawArgs"; declare -p l_rawArgsArray > /dev/null

        #echo "fullCallPath: $l_fullCallPath"
        #echo "serviceCodeName: $l_serviceCodeName"
        #echo "methodName: $l_methodName"
        #echo "rawArgs: $l_rawArgs"

        # Create "service call" from given input

        for i in "${!l_rawArgsArray[@]}"; do
            l_argument=$(echo "${l_rawArgsArray[i]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed -e 's/^"//' -e 's/"$//')
            l_dataType=${l_paramTypeArray[i]}
            if [ "$l_dataType" == "boolean" ]; then
                if [ "$l_argument" == "true" ]; then
                    l_argument=1
                elif [ "$l_argument" == "false" ]; then
                    l_argument=0
                else
                    Exit 1 "Parameter #$i of $l_methodName has to be of type '$l_dataType', but the value you provided was: '${l_argument}'!"
                fi
            elif [ "$l_dataType" == "int" ] && ! [[ $l_argument =~ ^\-?[0-9]+$ ]] ; then
                Exit 1 "Parameter #$i of $l_methodName has to be of type '$l_dataType', but the value you provided was: '${l_argument}'!"
            elif [ "$l_dataType" == "long" ] && ! [[ $l_argument =~ ^[0-9]+$ ]] ; then
                Exit 1 "Parameter #$i of $l_methodName has to be of type '$l_dataType', but the value you provided was: '${l_argument}'!"
            elif [ "$l_dataType" == "float" ] && ! [[ $l_argument =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                Exit 1 "Parameter #$i of $l_methodName has to be of type '$l_dataType', but the value you provided was: '${l_argument}'!"
            elif [ "$l_dataType" == "double" ] && ! [[ $l_argument =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                Exit 1 "Parameter #$i of $l_methodName has to be of type '$l_dataType', but the value you provided was: '${l_argument}'!"
            fi

            #echo "Index: '$i'"
            #echo "Data Type: '$dataType'"
            l_lowLevelDataType="$(ConvertDataType "${l_dataType}")"
            if [ "$l_lowLevelDataType" == "s16" ]; then
                l_shellServiceCall="${l_shellServiceCall} ${l_lowLevelDataType} '${l_argument}'"
            else
                l_shellServiceCall="${l_shellServiceCall} ${l_lowLevelDataType} ${l_argument}"
            fi
            #echo "Low Level Data Type: '$l_lowLevelDataType'"
            #echo "Argument: '$l_argument'"
        done
    fi

    #echo "Given call: $l_serviceCall"
    #echo "Method definition: $l_methodSignature"
    #echo "Shell command: $l_shellServiceCall"
    echo "$l_shellServiceCall"
}

CallServiceMethod () {
    l_serviceCall="${1-}"
    [ -n "$l_serviceCall" ] || Exit 1 "Service call not provided in CallServiceMethod"
    l_parcel="$(AndroidShell "$(ConvertServiceCallToShellCommand "${l_serviceCall}")")"

    l_fullCallPath=$(echo "$l_serviceCall" | cut -d'(' -f1)
    l_methodName=$(echo "$l_fullCallPath" | rev | cut -d'.' -f 1 | rev)
    l_serviceCodeName=$(echo "$l_fullCallPath" | rev | cut -d"." -f2-  | rev)
    if [[ $l_serviceCodeName == *"."* ]]; then # A service package name was given
        l_servicePackageName="$l_serviceCodeName"
        l_serviceCodeName="$(GetServiceCodeName "$l_servicePackageName")"
    else # A service code name was given
        l_servicePackageName="$(GetServicePackageName "$l_serviceCodeName")"
    fi

    # Get data types for method parameters
    l_methodSignature="$(GetMethodSignature "$l_servicePackageName" "$l_methodName")"

    l_returnDataType="$(echo "$l_methodSignature" | cut -d'(' -f1 | rev | cut -d' ' -f2 | rev)"

    ParseParcel "${l_parcel}" "${l_returnDataType}"
}

###
# list available service package names from connected android devices
# OUTPUTS:
#  services package names list
GetServicePackageNames () {
    l_packageNames="$(AndroidShell 'service list' | grep -oP '(?<=\[).+(?=\])')"
    [ -n "$l_packageNames" ] || Exit 1 "Unable to find services in GetServicePackageNames"
    echo "$l_packageNames"
}

###
# get service package name that implement a service name.
# ARGUMENTS:
#  a service name like: input, gpu, display, batterystats...
# OUTPUTS:
#  a service package name
GetServicePackageName () {
    l_service="${1-}"
    [ -n "$l_service" ] || Exit 1 "Service name was not provided in GetServicePackageName"
    l_packageName=$(AndroidShell 'service list' | sed -e '1d' -e 's/[0-9]*[[:space:]]'"$l_service"': \[\(.*\)\]/\1/p' -e 'd')
    [ -n "$l_packageName" ] || Exit 1 "Unable to find service package name for '$l_service' in GetServicePackageName"
    echo "$l_packageName"
}

###
# get service name from a service package name.
# ARGUMENTS:
#  a service name service name like: android.app.IUiModeManager, android.os.ISystemConfig, android.os.IPermissionController...
# OUTPUTS:
#  a service name like: overlay, package, power....
GetServiceCodeName () {
    l_packageName="${1-}"
    [ -n "$l_packageName" ] || Exit 1 "Package name was not provided in GetServiceCodeName"
    l_codeName=$(AndroidShell 'service list' | sed -e '1d' -e 's/[0-9]*[[:space:]]\(.*\): \['"$l_packageName"'\]/\1/p' -e 'd')
    [ -n "$l_codeName" ] || Exit 1 "Unable to find service code name for '$l_packageName'"
    echo "$l_codeName"
}

GetMethodSignature () {
    l_packageName="${1-}"; l_methodName="${2-}"
    [ -n "$l_packageName" ] || Exit 1 "Package name was not provided in GetmethodSignature"
    [ -n "$l_methodName" ] || Exit 1 "Method name was not provided in GetmethodSignature"
    if [[ $l_packageName != *"."* ]]; then
        l_packageName="$(GetServicePackageName "$l_packageName")"
    fi
    l_methodSignature="$(GetMethodSignaturesForPackage "$l_packageName" | grep " ${l_methodName}(")"
    echo "${l_methodSignature}"
}

###
# List methods from a service package name.
# the aidl file will be retieves from https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/android-${version}
# GLOBALS:
#  g_repoUrl filled by then Init method
#  g_aidlFileList list of aidl files filed by Init method
#  g_cacheDir if offline mode
# ARGUMENTS:
#  a service name service name like: android.app.IUiModeManager, android.os.ISystemConfig, android.os.IPermissionController...
# OUTPUTS:
#  list of aidl signatures.
GetMethodSignaturesForPackage () {
    l_packageName="${1-}"
    [ -n "$l_packageName" ] || Exit 1 "Package name was not provided in GetMethodSignaturesForPackage"
    [ -n "$g_repoUrl" ] || Exit 1 "Android source code repository URL was empty in GetMethodSignaturesForPackage (Did you call Init first?)"
    [ -n "$g_aidlFileList" ] || Exit 1 "AIDL file list was empty in GetMethodSignaturesForPackage (Did you call Init first?)"

    l_packageFilePath="$(echo "$l_packageName" | tr '.' '/')\.aidl"
    l_servicePath="$(echo "$g_aidlFileList" | grep -m 1 "$l_packageFilePath\$")"

    if [ -f "$l_servicePath" ]; then
        l_serviceSource="$(cat "${g_cacheDir}/${l_servicePath}")"
    else
        l_serviceSource="$(GetSourceFile "$l_servicePath")"
    fi

    echo "${l_serviceSource}" | sed -e '1,/interface/d' \
    -e '/^$/d' \
    -e 's/^[[:space:]]*//' \
    -e '/^[^a-zA-Z]/d' \
    -e '/^[^;]*$/{$!N}' \
    -e '$d' \
    -e 's/\(^\|\n\)[[:space:]]*\|\([[:space:]]\)\{2,\}/\2/g' | \
    sed -e ':x;N;s/\([^;]\)\n/\1/;bx' |
    sed -e "s/ ,/, /g" |
    sed -E "s/,([^[:space:]])/, \1/g"
}

GetMethodIndex () {
    l_packageName="${1-}"; l_methodName="${2-}"
    [ -n "$l_packageName" ] || Exit 1 "Package name was not provided in GetmethodSignature"
    [ -n "$l_methodName" ] || Exit 1 "Method name was not provided in GetmethodSignature"
    l_methodindex="$(GetMethodSignaturesForPackage "$l_packageName" | cat -n | grep " ${l_methodName}(" | sed -e 's/^[[:space:]]*//' | cut -d$'\t' -f1)"
    echo "${l_methodindex}"
}

GetAndroidVersion () {
    l_androidVersion="$(AndroidShell 'getprop ro.build.version.release')"
    [ -n "$l_androidVersion" ] || Exit 1 "Failed to retrieve Android version in GetAndroidVersion"
    echo "${l_androidVersion}"
}

GetRomName () {
    l_lineageVersion="$(AndroidShell 'getprop ro.lineage.build.version')"
    if [ "$l_lineageVersion" != "" ]; then
        echo "lineage/${l_lineageVersion}"
    else
        l_androidVersion="$(GetAndroidVersion)"
        echo "stock/${l_androidVersion}"
    fi
}

GetSourceRepoUrl () {
    l_androidVersion="$(GetAndroidVersion)"
    l_lineageVersion="$(AndroidShell 'getprop ro.lineage.build.version')"
    if [ "${l_lineageVersion}" != "" ]; then
        #l_branches="$(git ls-remote https://github.com/LineageOS/android_frameworks_base.git | cut -d'/' -f3 | cut -d'^' -f1 | grep lineage-)"
        l_repoUrl="https://raw.githubusercontent.com/LineageOS/android_frameworks_base/lineage-${l_lineageVersion}"
    elif [ "${l_androidVersion}" != "" ]; then
        l_tag="$(git ls-remote --tags --sort="v:refname" https://android.googlesource.com/platform/frameworks/base.git | cut -d'/' -f3 | cut -d'^' -f1 | grep android-${l_androidVersion} | tail -1)"
        l_repoUrl="https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/${l_tag}"
    fi
    l_repoStatus="$(curl -s -o /dev/null -w "%{http_code}" "${l_repoUrl}/Android.bp")"
    if [ "$l_repoStatus" != "200" ]; then
        Exit 1 "Failed to find a working Android source code repository for this Android version / ROM in GetSourceRepoUrl (HTTP status '${l_repoStatus}' for '${l_repoUrl}')"
    fi
    echo "$l_repoUrl"
}

###
# Get file content from repo
# GLOBALS:
#  g_repoUrl filled by then Init method
# ARGUMENTS:
#  $1 file to download
# RETURN:
#  File content
GetSourceFile () {
    l_file="${1-}"
    [ -n "$l_file" ] || Exit 1 "File was not provided in GetSourceFile"
    [ -n "$g_repoUrl" ] || Exit 1 "Android source code repository URL was empty in GetSourceFile (Did you call Init first?)"
    wget -qO - "$g_repoUrl/$l_file"
}

###
# list all aidl files
# GLOBALS:
#  g_repoUrl filled by then Init method contains an url like https://raw.githubusercontent.com/aosp-mirror/platform_frameworks_base/android-11.0.0_r35
# OUTPUTS:
#  path to all aidl files in the current branch
GetServiceAidlFileNames () {
    [ -n "$g_repoUrl" ] || Exit 1 "Android source code repository URL was empty in GetServiceAidlFileNames (Did you call Init first?)"
    # l_githubUser should contains aosp-mirror
    l_githubUser="$(echo "$g_repoUrl" | cut -d'/' -f 4)"
    # l_githubProject should contains platform_frameworks_base
    l_githubProject="$(echo "$g_repoUrl" | cut -d'/' -f 5)"
    # l_branch should contains android-XX.Y.Z-revision
    l_branch="$(echo "$g_repoUrl" | cut -d'/' -f 6)"
    # build github api to list all files in a branch
    l_recursiveFileTreeUrl="https://api.github.com/repos/${l_githubUser}/${l_githubProject}/git/trees/${l_branch}?recursive=1"
    # Extract all .aidl file paths from the recursive file tree:
    curl -s "${l_recursiveFileTreeUrl}" | jq -r '.tree|map(.path|select(test("\\.aidl")))[]' | sort -u
}

###
# get android service datatype from aidl datatype.
# ARGUMENTS:
#  $1 aidl parameter datatype (int, long, float...)
# RETURN:
#  android service call datatype (i32, i64, f...)
ConvertDataType () {
    # Note: I don't know if this conversion (especially for different architectures like arm64) would always be accurate!
    # Note 2: I have no clue how you could pass or convert Arrays, Lists, Objects, Maps, etc.
    #By default, AIDL supports the following data types:
    #
    #    All primitive types in the Java programming language (such as int, long, char, boolean, and so on)
    #    Arrays of primitive types such as int[]
    #    String
    #    CharSequence
    #    List
    #
    #    All elements in the List must be one of the supported data types in this list or one of the other AIDL-generated interfaces or parcelables you've declared. A List may optionally be used as a parameterized type class (for example, List<String>). The actual concrete class that the other side receives is always an ArrayList, although the method is generated to use the List interface.
    #    Map
    #
    #    All elements in the Map must be one of the supported data types in this list or one of the other AIDL-generated interfaces or parcelables you've declared. Parameterized type maps, (such as those of the form Map<String,Integer>) are not supported. The actual concrete class that the other side receives is always a HashMap, although the method is generated to use the Map interface. Consider using a Bundle as an alternative to Map.
    l_dataType="${1-}"
    [ -n "$l_dataType" ] || Exit 1 "Data type was not provided in ConvertDataType"
    if [ "$l_dataType" = "void" ] || [ "$l_dataType" = "oneway void" ]; then
        echo ""
    elif [ "$l_dataType" = "int" ] || [ "$l_dataType" = "in int" ] || [ "$l_dataType" = "boolean" ] || [ "$l_dataType" = "in boolean" ] || [ "$l_dataType" = "char" ] || [ "$l_dataType" = "in char" ]; then
        echo "i32"
    elif [ "$l_dataType" = "long" ] || [ "$l_dataType" = "in long" ]; then
        echo "i64"
    elif [ "$l_dataType" = "String" ] || [ "$l_dataType" = "in String" ]; then
        echo "s16"
    elif [ "$l_dataType" = "float" ] || [ "$l_dataType" = "in float" ]; then
        echo "f"
    elif [ "$l_dataType" = "double" ] || [ "$l_dataType" = "in double" ]; then
        echo "d"
    else
        echo "i64"
    fi
}

###
# Extract data from Parcel.
# ARGUMENTS:
#  $1 parcel as return by adb (Hexa + text)
# RETURN:
#  parcel hexadecimal data.
GetParcelDataAsHex () {
    l_parcel="${1-}"
    [ -n "$l_parcel" ] || Exit 1 "Parcel not provided in GetParcelDataAsHex"
    if [ "$(echo "$l_parcel" | head -1)" == "Result: Parcel(" ]; then
        l_parcelHexData="$(echo "$l_parcel" | grep 0x | cut -d: -f2- | cut -d\' -f1 | tr -d [:space:])"
    else
        l_parcelHexData="$(echo "$l_parcel" | tr -d ' ' | cut -d'(' -f2- | cut -d"'" -f1 | tr -d '\n')"
    fi
    echo "$l_parcelHexData"
}

###
# TODO
# ARGUMENTS:
#  $1 parcel as return by adb (Hexa + text)
#  $2 
# RETURN:
#  
ParseParcel () {
    l_parcel="${1-}"; l_dataType="${2-}"
    [ -n "$l_parcel" ] || Exit 1 "Parcel not provided in ParseParcel"
    [ -n "$l_dataType" ] || Exit 1 "Data type not provided in ParseParcel"
    l_hexData="$(GetParcelDataAsHex "$l_parcel")"
    if [ "$l_dataType" == "boolean" ]; then
        if [ "$l_hexData" == "0000000000000000" ]; then
            echo false
        elif [ "$l_hexData" == "0000000000000001" ]; then
            echo true
        else
            Exit 1 "Error trying to determine boolean value in ParseParcel (Got '$l_hexData')"
        fi
    elif [ "$l_dataType" == "int" ] || [ "$l_dataType" == "long" ]; then
        echo "$((0x${l_hexData}))"
    elif [ "$l_dataType" == "float" ]; then
        echo "$((0x${l_hexData}))"
    elif [ "$l_dataType" == "String" ]; then
        echo "$l_hexData" | fold -w8 | sed -E 's/(.{2})(.{2})(.{2})(.{2})/\4\3\2\1/' | xxd -r -p | tr -d '\0'
    elif [ "$l_dataType" == "void" ]; then
        : # Do nothing
    else
        echo "Decoding Parcels of type '${l_dataType}' is not yet supported!"
        echo "Any help with this would be appreciated!"
        echo "Here is the raw Parcel response:"
        echo "${l_parcel}"
    fi
}

###
# TODO
# GLOBALS:
#  
# ARGUMENTS:
#  $1 
# RETURN:
#  
AidlSyntaxHighlight () {
    l_code="${1-}"
    [ -n "$l_code" ] || Exit 1 "No code was provided in AidlSyntaxHighlight"

    l_codeInput="$(echo "${l_code}" | sed -e "s/()/(a a)/g")"

    l_highlightedCode="$(echo -e "${l_codeInput}" |
    sed '
        s/^ *\([^(,)]\+\) \+\([^ (,)]\+\)\([(,)]\)\(.*\)/\4\n{FUNCRET}\1{END} {FUNCNAME}\2{END}{SEP}\3{END}/;
        h;
        :a; {
            /^ *\([^(,)]\+\) \+\([^ (,)]\+\)\([(,)]\)\([^\n]*\)\n\(.*\)$/{
                s//\4\n\5{PARTYPE}\1{END} {PARNAME}\2{END}{SEP}\3{END}/
                b a
            }
        }
        s/^;\(.*\)/\1{SEP};{END}/
    ' | sed -e '/^$/d' \
            -e "s/,/, /g" \
            -e "s/{PARTYPE}a{END} {PARNAME}a{END}//g" \
            -e "s/{FUNCRET}/${g_blue}/g" \
            -e "s/{FUNCNAME}/${g_red}/g" \
            -e "s/{PARTYPE}/${g_blue}/g" \
            -e "s/{PARNAME}/${g_green}/g" \
            -e "s/{SEP}/${g_yellow}/g" \
            -e "s/{END}/${g_nc}/g")"
    echo "${l_highlightedCode}"
}

###
# Set binary name to call to access android device.
# get first android serial.
# GLOBALS:
#  g_shellType is modified to contains android serial id
# ARGUMENTS:
#  $1 adb
# RETURN:
#  nothing or exit the script with an error message 
SetShellType () {
    g_shellType="${1-}"
    [ -n "$g_shellType" ] || Exit 1 "Shell type was not provided in SetShellType"
    if [ "$g_shellType" == "adb" ]; then
        g_adbSerial="${g_adbSerial:-$(adb devices | sed -e '1d' -e '2s/[[:space:]].*//' -e 'q')}"
    fi
}

###
# Select a specific android device by serial id
# ARGUMENTS:
#  $1 serial
# RETURN:
#  nothing or exit the script with an error message 
SetAdbDevice () {
    g_adbSerial="${1-}"
    [ -n "$g_adbSerial" ] || Exit 1 "Adb device was not provided in SetAdbDevice"
}

###
# Execute an adb shell command.
# GLOBALS:
#  g_shellType defined by SetShellType only adb is currently supported
#  g_adbSerial android serial number defined by SetShellType or SetShellType
# ARGUMENTS:
#  $1 command to execute
# RETURN:
#  adb shell result
AndroidShell () {
    if [ "$g_shellType" == "adb" ]; then
        adb ${g_adbSerial:+-s $g_adbSerial} shell -T -x "$1" | tr -d '\r'
    else
        su -c "$1"
    fi
}

###
# Assert needed binary are availables.
# ARGUMENTS:
#  $# list of needed binary
# RETURN:
#  nothing or exit the script with an error message 
AssertExecutablesAreAvailable () {
    l_bins=
    for b in "$@"; do [ -n "$(command -v "$b" 2>/dev/null)" ] || l_bins="${l_bins-}$b "; done
    if [ ${#l_bins} -eq 0 ]; then return 0; fi
    printf '%s\n' "Cannot find the following executables:" "$l_bins"
    Exit 1 "Exiting due to insufficient dependencies"
}

###
# Exit script with the given code and error message.
# ARGUMENTS:
#  [$1] error code (Optional)
#  [$2] error message (Optional)
# RETURN:
#  Exit the script
Exit () {
    if [ $# -ge 1 ] && [ -n "$1" ] && [ "$1" -eq "$1" ] 2>/dev/null; then exitCode="$1"; shift; fi
    if [ $# -ge 1 ] ; then printf '%s\n' "$@" 1>&2; fi
    if (return 0 2>/dev/null); then # file was sourced rather than run
        kill -INT 0 # Ensures exiting of the script, even from nested subshells
    else
        exit "${exitCode:-1}"
    fi
}

AssertExecutablesAreAvailable 'bash' 'git' 'wget' 'tr' 'sed' 'cut' 'grep' 'head' 'tail' 'printf' 'cat' 'sort' 'rev' 'xxd' 'jq'
