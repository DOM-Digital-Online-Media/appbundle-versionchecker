#!/bin/bash

# Usage: ./extract-aab-version.sh path/to/app.aab

set -e

AAB="$1"
BUNDLETOOL_JAR="bundletool.jar"
TMP_DIR="tmp_aab_extract"
OUT_APKS="$TMP_DIR/output.apks"
APK="$TMP_DIR/universal.apk"
APKTOOL_OUT="$TMP_DIR/apk_out"
KEYSTORE="/app/debug.keystore"

# Use native aapt2 if available and running on ARM
AAPT2_PATH=""
if [[ "$(uname -m)" == "arm64" || "$(uname -m)" == "aarch64" ]]; then
  AAPT2_NATIVE="/app/aapt2-bin/aapt2"
  if [[ -f "$AAPT2_NATIVE" ]]; then
    AAPT2_PATH="--aapt2=$AAPT2_NATIVE"
    echo "Using native ARM64 aapt2 binary: $AAPT2_NATIVE"
  fi
fi

if [ -z "$AAB" ]; then
  echo "Usage: $0 path/to/app.aab"
  exit 1
fi

# Ensure bundletool is available
if [ ! -f "$BUNDLETOOL_JAR" ]; then
  echo "Downloading bundletool..."
  curl -L -o "$BUNDLETOOL_JAR" https://github.com/google/bundletool/releases/download/1.15.6/bundletool-all-1.15.6.jar
fi

# Ensure apktool is installed
if ! command -v apktool &> /dev/null; then
  echo "apktool not found. Please install it: brew install apktool"
  exit 1
fi

# Clean temp
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Extract APK from AAB
echo "Extracting universal APK from AAB..."
java -jar "$BUNDLETOOL_JAR" build-apks \
  --bundle="$AAB" \
  --output="$OUT_APKS" \
  --mode=universal \
  --overwrite \
  $AAPT2_PATH \
  --ks="$KEYSTORE" \
  --ks-pass=pass:android \
  --ks-key-alias=androiddebugkey \
  --key-pass=pass:android || { echo "❌ bundletool failed"; exit 1; }

if ! unzip -p "$OUT_APKS" universal.apk > "$APK"; then
  echo "❌ Failed to extract universal.apk from .apks"
  exit 1
fi

# Unpack APK
echo "Unzipping APK..."
unzip -p "$OUT_APKS" universal.apk > "$APK"

# Decode APK
echo "Decoding APK..."
apktool d -f "$APK" -o "$APKTOOL_OUT" > /dev/null

# Extract version info
echo "Version info from apktool.yml:"
grep -E 'versionCode|versionName' "$APKTOOL_OUT/apktool.yml"

# Cleanup
rm -rf "$TMP_DIR"