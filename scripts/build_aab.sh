#!/bin/bash
# ─────────────────────────────────────────────────
# Minivo — Build Release AAB + APK (prod flavor)
# Builds prod artifacts for Play Store and sideload.
#
# Auto-bumps version in pubspec.yaml before building.
# Default: AUTO mode — scans commits since last `v*` git tag and picks
# bump level from conventional-commit prefixes:
#   feat!: / BREAKING CHANGE  → major  (X+1.0.0)
#   feat:                     → minor  (X.Y+1.0)
#   anything else             → patch  (X.Y.Z+1)
# versionCode always +1.
#
# Manual override:
#   ./scripts/build_aab.sh patch | minor | major
#   ./scripts/build_aab.sh code   → versionCode +1, keep name
#   ./scripts/build_aab.sh none   → use current pubspec value as-is
#
# After successful build, tags HEAD with v<NEW_NAME> so next run knows
# where to start scanning commits from.
# ─────────────────────────────────────────────────

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

BUMP_TYPE="${1:-auto}"

CURRENT=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d '[:space:]')
NAME="${CURRENT%+*}"     # X.Y.Z
CODE="${CURRENT#*+}"     # N

IFS='.' read -r MAJOR MINOR PATCH <<< "$NAME"

# ── auto: detect bump level from commits since last v* tag ──────────
if [ "$BUMP_TYPE" = "auto" ]; then
  LAST_TAG=$(git tag --list 'v*' --sort=-v:refname | head -n1)
  if [ -z "$LAST_TAG" ]; then
    RANGE="HEAD"
    echo -e "${YELLOW}No previous v* tag — scanning entire history${NC}"
  else
    RANGE="${LAST_TAG}..HEAD"
    echo -e "${CYAN}Scanning commits in ${RANGE}${NC}"
  fi

  COMMITS=$(git log --format=%s%n%b "$RANGE" 2>/dev/null || true)

  if echo "$COMMITS" | grep -qE "^[a-z]+(\([^)]+\))?!:|BREAKING CHANGE"; then
    BUMP_TYPE="major"
  elif echo "$COMMITS" | grep -qE "^feat(\([^)]+\))?:"; then
    BUMP_TYPE="minor"
  else
    BUMP_TYPE="patch"
  fi
  echo -e "${CYAN}Auto-detected bump: ${BOLD}${BUMP_TYPE}${NC}"
fi

case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1)); PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  code)
    ;;
  none)
    ;;
  *)
    echo -e "${RED}Unknown bump type: $BUMP_TYPE (expected: auto|patch|minor|major|code|none)${NC}"
    exit 1
    ;;
esac

if [ "$BUMP_TYPE" = "none" ]; then
  NEW_NAME="$NAME"
  NEW_CODE="$CODE"
else
  NEW_NAME="${MAJOR}.${MINOR}.${PATCH}"
  NEW_CODE=$((CODE + 1))
  # macOS BSD sed needs '' after -i
  sed -i '' "s/^version: .*/version: ${NEW_NAME}+${NEW_CODE}/" pubspec.yaml
fi

echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  Minivo — Release Build (prod)        ${NC}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}"
echo -e "  Previous: ${BOLD}${NAME}+${CODE}${NC}"
echo -e "  New:      ${BOLD}${NEW_NAME}+${NEW_CODE}${NC}  (bump: ${BUMP_TYPE})"
echo ""

echo -e "${CYAN}Building AAB (Play Store)...${NC}"
flutter build appbundle --flavor prod -t lib/main_prod.dart --release

echo ""
echo -e "${CYAN}Building APK (sideload / Samsung)...${NC}"
flutter build apk --flavor prod -t lib/main_prod.dart --release

echo ""
echo -e "${GREEN}${BOLD}✓ Build complete${NC}"
echo -e "  Version: ${BOLD}${NEW_NAME}+${NEW_CODE}${NC}"
echo -e "  AAB: build/app/outputs/bundle/prodRelease/app-prod-release.aab"
echo -e "  APK: build/app/outputs/flutter-apk/app-prod-release.apk"
echo ""

# ── Tag HEAD so next auto-detect knows where to start ───────────────
if [ "$BUMP_TYPE" != "none" ]; then
  TAG="v${NEW_NAME}"
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo -e "  ${YELLOW}Tag ${TAG} already exists — skipping${NC}"
  else
    git tag -a "$TAG" -m "Release ${NEW_NAME}+${NEW_CODE}"
    echo -e "  ${GREEN}Tagged HEAD as ${TAG}${NC}"
  fi
fi

echo ""
echo -e "  ${YELLOW}Next:${NC}"
echo -e "    1. Upload AAB to Play Console"
echo -e "    2. Commit + push: ${BOLD}git push && git push --tags${NC}"
