#!/bin/sh
set -eu

RELEASE=https://github.com/barnybug/cli53/releases
NAME=cli53
VERSION=0.8.16
DEST=bin

mkdir -p $DEST

ARCH=$(uname -m)
OS=$(uname -s)

case "$ARCH" in
  armv6*) ARCH="arm";;
  armv7*) ARCH="arm";;
  aarch64) ARCH="arm64";;
  x86) ARCH="386";;
  x86_64) ARCH="amd64";;
  i686) ARCH="386";;
  i386) ARCH="386";;
esac

case "$OS" in
	Linux*) OS='linux' ;;
	Darwin*) OS='mac' ;;
	MINGW*) OS='windows';;
	MSYS*) OS='windows';;
esac

URL="$RELEASE/download/$VERSION/$NAME-$OS-$ARCH"
if [ "$OS" == "windows" ]; then URL="$URL.exe"; fi

echo "Downloading: $URL"
curl -Lo $DEST/$NAME $URL
chmod 755 $DEST/$NAME

