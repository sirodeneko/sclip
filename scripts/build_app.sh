#!/bin/zsh
set -euo pipefail
setopt null_glob

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

APP_NAME="${APP_NAME:-sclip}"
BUNDLE_ID="${BUNDLE_ID:-com.example.sclip}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
ARCHS="${ARCHS:-}"
export SWIFTPM_DISABLE_SANDBOX=1

INFO_PLIST_SRC="$ROOT_DIR/Resources/Info.plist"
ENTITLEMENTS="$ROOT_DIR/Resources/Entitlements.plist"

if [[ ! -f "$INFO_PLIST_SRC" ]]; then
  echo "Missing Info.plist at $INFO_PLIST_SRC" >&2
  exit 1
fi

cd "$ROOT_DIR"

build_for_arch() {
  local arch="$1"
  if [[ -z "$arch" ]]; then
    echo "Building (release)…" >&2
    swift build -c release --disable-sandbox >/dev/null
    swift build -c release --disable-sandbox --show-bin-path
    return
  fi
  echo "Building (release, $arch)…" >&2
  swift build -c release --disable-sandbox --arch "$arch" >/dev/null
  swift build -c release --disable-sandbox --arch "$arch" --show-bin-path
}

ARCH_LIST=()
if [[ "$ARCHS" == "universal" || "$ARCHS" == "universal2" ]]; then
  ARCH_LIST=("arm64" "x86_64")
elif [[ -n "$ARCHS" ]]; then
  ARCH_LIST=(${=ARCHS})
fi

BIN_PATH=""
BIN_DIR=""
if (( ${#ARCH_LIST[@]} == 0 )); then
  BIN_DIR="$(build_for_arch "")"
  BIN_PATH="$BIN_DIR/mac-clipboard-app"
  if [[ ! -f "$BIN_PATH" ]]; then
    echo "Missing binary at $BIN_PATH" >&2
    exit 1
  fi
else
  FIRST_BIN_DIR=""
  INPUTS=()
  for a in "${ARCH_LIST[@]}"; do
    d="$(build_for_arch "$a")"
    if [[ -z "$FIRST_BIN_DIR" ]]; then
      FIRST_BIN_DIR="$d"
    fi
    p="$d/mac-clipboard-app"
    if [[ ! -f "$p" ]]; then
      echo "Missing binary at $p" >&2
      exit 1
    fi
    INPUTS+=("$p")
  done
  BIN_DIR="$FIRST_BIN_DIR"
  FAT_BIN="$ROOT_DIR/.build/tmp/${APP_NAME}-universal"
  mkdir -p "$(dirname "$FAT_BIN")"
  lipo -create "${INPUTS[@]}" -output "$FAT_BIN"
  BIN_PATH="$FAT_BIN"
fi

DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cp "$INFO_PLIST_SRC" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :NSServices:0:NSPortName $BUNDLE_ID" "$CONTENTS_DIR/Info.plist" >/dev/null

if [[ -d "$BIN_DIR" ]]; then
  for b in "$BIN_DIR"/*.bundle; do
    if [[ -d "$b" ]]; then
      cp -R "$b" "$RESOURCES_DIR/"
    fi
  done
fi

if [[ -f "$ROOT_DIR/Sources/mac-clipboard-app/AppResources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Sources/mac-clipboard-app/AppResources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [[ -f "$ROOT_DIR/AppResources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/AppResources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

echo "Signing ($SIGN_IDENTITY)…"
codesign --force --deep --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Done: $APP_DIR"
