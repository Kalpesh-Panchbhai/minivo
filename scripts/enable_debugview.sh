#!/bin/bash
# Enable Firebase Analytics DebugView for the dev flavor.
# Invoked as a Before Launch task by dev run configs.
set -e

# Locate adb — IntelliJ's Before Launch shell may not have PATH inherited.
if command -v adb >/dev/null 2>&1; then
  ADB=adb
elif [ -n "$ANDROID_HOME" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
  ADB="$ANDROID_HOME/platform-tools/adb"
elif [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
  ADB="$HOME/Library/Android/sdk/platform-tools/adb"
elif [ -x "$HOME/Library/Android/Sdk/platform-tools/adb" ]; then
  ADB="$HOME/Library/Android/Sdk/platform-tools/adb"
else
  echo "Warning: adb not found. Skipping Android DebugView setup." >&2
  exit 0
fi

if [ -z "$("$ADB" devices | sed '1d' | grep -w device)" ]; then
  echo "Warning: no Android device connected — DebugView prop will not be set." >&2
  exit 0
fi

PACKAGE="com.puzzloragames.dropzy"
"$ADB" shell setprop debug.firebase.analytics.app "$PACKAGE"
echo "Firebase DebugView enabled for $PACKAGE"
echo ""
echo "Tip (iOS): launch from Xcode with -FIRDebugEnabled in scheme arguments,"
echo "or run: flutter run --flavor dev -t lib/main_dev.dart --dart-define=FIREBASE_DEBUG=true"
