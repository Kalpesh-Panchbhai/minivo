#!/bin/bash
# ─────────────────────────────────────────────────
# Minivo — Build Release AAB + APK (prod flavor)
# Builds prod artifacts for Play Store and sideload.
# Run manually: ./scripts/build_aab.sh
# ─────────────────────────────────────────────────

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')

echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  Minivo — Release Build (prod)        ${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "  Version: ${BOLD}${VERSION}${NC}"
echo ""

echo -e "${CYAN}Building AAB (Play Store)...${NC}"
flutter build appbundle --flavor prod -t lib/main_prod.dart --release

echo ""
echo -e "${CYAN}Building APK (sideload / Samsung)...${NC}"
flutter build apk --flavor prod -t lib/main_prod.dart --release

echo ""
echo -e "${GREEN}${BOLD}✓ Build complete${NC}"
echo -e "  AAB: build/app/outputs/bundle/prodRelease/app-prod-release.aab"
echo -e "  APK: build/app/outputs/flutter-apk/app-prod-release.apk"
echo ""
echo -e "  ${YELLOW}Next: Upload AAB to Play Console${NC}"
