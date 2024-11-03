#!/bin/bash

VERSION=$1

if [ "$VERSION" == "" ]; then
	echo "Usage: ./package.sh <version>"
	echo "Example: ./package.sh 1.0.0-1"
	exit
fi

zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux

mkdir -p xpose_$VERSION/DEBIAN
mkdir -p xpose_$VERSION/usr/local/bin

echo "Package: xpose
Version: $VERSION
Section: base
Priority: optional
Architecture: amd64
Depends: ffmpeg, x11-xserver-utils
Maintainer: Joe Koop <joekoop.com>
Description: Auto-expose an X output.
 Xpose is a tool that captures the screen, sorts the pixel values, and then configures the output to compensate for a dim picture." > xpose_$VERSION/DEBIAN/control

cp xpose zig-out/bin/xpose-helper xpose_1.0.0-1/usr/local/bin/

dpkg-deb --build xpose_$VERSION
