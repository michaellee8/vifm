#! /bin/bash

set -x
set -e

# Reference: https://docs.appimage.org/packaging-guide/from-source/native-binaries.html#id2

# building in temporary directory to keep system clean
# use RAM disk if possible (as in: not building on CI system 
# like Travis, and RAM disk is available)
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" appimage-build-XXXXXX)

# make sure to clean up build dir, even if errors occur
cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}
trap cleanup EXIT

# store repo root as variable
REPO_ROOT="$(git rev-parse --show-toplevel)"
OLD_CWD=$(readlink -f .)

mkdir "$BUILD_DIR/AppDir"

# Install to the corresponding AppDir
# It is assumed that this script runs after a successful make only

make DESTDIR="$BUILD_DIR/AppDir" install

# Since the make script produce binaries to /usr/local to default, we need to 
# make it /usr so linuxdeploy will recognize it.

pushd "$BUILD_DIR"

pushd AppDir

mv usr/local .
rm -r usr
mv local usr

# Downloading linuxdeploy

curl -o ./linuxdeploy -L \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage

chmod +x ./linuxdeploy

# Custom AppRun to provide $ARGV0 issues when used with zsh
# Reference: https://github.com/neovim/neovim/blob/master/scripts/genappimage.sh
# Reference: https://github.com/neovim/neovim/issues/9341

cat << 'EOF' > AppRun
#!/bin/bash
unset ARGV0
exec "$(dirname "$(readlink  -f "${0}")")/usr/bin/nvim" ${@+"$@"}
EOF
chmod 755 AppRun

popd

./linuxdeploy --appdir AppDir --output appimage