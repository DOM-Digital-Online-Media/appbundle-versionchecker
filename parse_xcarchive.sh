#!/bin/bash
set -e

ROOT="$1"
XCARCHIVE=$(find "$ROOT" -type d -name '*.xcarchive' -print -quit)

# Fallback: treat root as the archive if no .xcarchive found
if [ -z "$XCARCHIVE" ]; then
  if [[ "$ROOT" == *.xcarchive && -d "$ROOT" ]]; then
    XCARCHIVE="$ROOT"
  else
    echo "No .xcarchive directory found inside $ROOT"
    exit 1
  fi
fi

INFO_PLIST="$XCARCHIVE/Info.plist"
echo "Using archive path: $XCARCHIVE"
echo "Looking for Info.plist at: $INFO_PLIST"

if [ ! -f "$INFO_PLIST" ]; then
  echo "Info.plist not found in: $INFO_PLIST"
  exit 1
fi

echo "Extracting version info from $INFO_PLIST ..."

VERSION_NAME=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :ApplicationProperties:CFBundleVersion" "$INFO_PLIST" 2>/dev/null || true)

if [ -z "$VERSION_NAME" ] || [ -z "$BUILD_NUMBER" ]; then
  echo "❌ Failed to extract versionName or buildNumber"
  echo "Contents of $INFO_PLIST:"
  cat "$INFO_PLIST"
  exit 1
fi

echo "versionName: $VERSION_NAME"
echo "buildNumber: $BUILD_NUMBER"
