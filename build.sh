#!/bin/bash

# This build script combines `android-svc.sh` and `android-svc-lib.sh` into a single bash script called `android-svc`.

mkdir -p ./build && \
rm -f ./build/android-svc && \
sed -e '/#ANDROID_SVC_LIB_BEGIN/,/#ANDROID_SVC_LIB_END/!b' -e '/#ANDROID_SVC_LIB_END/!d;r ./android-svc-lib.sh' -e 'd' ./android-svc.sh > ./build/android-svc && \
chmod +x ./build/android-svc && \
echo "Standalone build successful!"

if command -v termux-create-package &> /dev/null; then
    mkdir -p ./build && \
    rm -f ./build/*.deb && \
    termux-create-package ./manifest.json && \
    mv *.deb ./build/ && \
    echo "Termux package build successful!"
else
    echo "Package 'termux-create-package' is missing. Try installing it via 'pip3 install termux-create-package'."
fi