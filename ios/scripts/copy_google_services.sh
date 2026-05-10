#!/bin/bash
# Copies the correct GoogleService-Info.plist based on the Flutter flavor.
# Add this as a "Run Script" build phase in Xcode BEFORE "Copy Bundle Resources".

FLAVOR="${DART_DEFINES}"

# Decode base64-encoded DART_DEFINES to find the flavor
for define in $(echo "$DART_DEFINES" | tr ',' '\n'); do
  decoded=$(echo "$define" | base64 --decode 2>/dev/null || echo "$define")
  if [[ "$decoded" == dart.vm.product=* ]] || [[ "$decoded" == dart.vm.profile=* ]]; then
    continue
  fi
  echo "DEFINE: $decoded"
done

# Fallback: use CONFIGURATION (Debug-dev, Release-prod, etc.)
if [[ "$CONFIGURATION" == *"-prod"* ]] || [[ "$CONFIGURATION" == *"Release"* && "$CONFIGURATION" != *"-dev"* ]]; then
  SOURCE="$SRCROOT/Runner/GoogleService-Info-Prod.plist"
  echo "Using PROD GoogleService-Info.plist"
else
  SOURCE="$SRCROOT/Runner/GoogleService-Info-Dev.plist"
  echo "Using DEV GoogleService-Info.plist"
fi

DEST="$SRCROOT/Runner/GoogleService-Info.plist"

if [ ! -f "$SOURCE" ]; then
  echo "error: $SOURCE not found. Run flutterfire configure for both environments."
  exit 1
fi

cp "$SOURCE" "$DEST"
echo "Copied $SOURCE → $DEST"
