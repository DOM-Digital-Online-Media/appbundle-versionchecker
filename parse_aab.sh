#!/bin/bash
set -e

AAB="$1"
BUNDLETOOL_JAR="bundletool.jar"
TMP_DIR="tmp_aab_extract"
OUT_APKS="$TMP_DIR/output.apks"
APK="$TMP_DIR/universal.apk"
KEYSTORE="/app/debug.keystore"

if [ -z "$AAB" ]; then
  echo "Usage: $0 path/to/app.aab"
  exit 1
fi

if [ ! -f "$BUNDLETOOL_JAR" ]; then
  echo "Downloading bundletool..."
  curl -L -o "$BUNDLETOOL_JAR" https://github.com/google/bundletool/releases/download/1.15.6/bundletool-all-1.15.6.jar
fi

# Clean temp
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "Extracting universal APK from AAB..."
java -jar "$BUNDLETOOL_JAR" build-apks \
  --bundle="$AAB" \
  --output="$OUT_APKS" \
  --mode=universal \
  --overwrite \
  --ks="$KEYSTORE" \
  --ks-pass=pass:android \
  --ks-key-alias=androiddebugkey \
  --key-pass=pass:android || { echo "❌ bundletool failed"; exit 1; }

echo "Unpacking APK..."
unzip -p "$OUT_APKS" universal.apk > "$APK"

echo "Dumping version info using aapt2..."
aapt2_path=$(which aapt2)
"$aapt2_path" dump badging "$APK" | grep version