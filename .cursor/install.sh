#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Batak AI Android/Kotlin project.
# Installs the Android SDK command-line tools and the build components needed
# to compile and assemble the app, then exposes ANDROID_HOME to interactive
# shells. Safe to re-run: every step checks for existing state first.
set -euo pipefail

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
CMDLINE_VERSION="11076708"
PLATFORM="platforms;android-34"
BUILD_TOOLS="build-tools;34.0.0"

mkdir -p "$ANDROID_SDK_ROOT"

# 1. Command-line tools (sdkmanager) -----------------------------------------
SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  echo "==> Installing Android command-line tools"
  tmp_zip="$(mktemp --suffix=.zip)"
  curl -fsSL -o "$tmp_zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VERSION}_latest.zip"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/tmp"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/tmp"
  unzip -q "$tmp_zip" -d "$ANDROID_SDK_ROOT/cmdline-tools/tmp"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mv "$ANDROID_SDK_ROOT/cmdline-tools/tmp/cmdline-tools" \
     "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/tmp" "$tmp_zip"
else
  echo "==> Android command-line tools already present"
fi

# 2. SDK packages ------------------------------------------------------------
echo "==> Accepting SDK licenses"
yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 || true

echo "==> Installing platform-tools, $PLATFORM, $BUILD_TOOLS"
"$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" "$PLATFORM" "$BUILD_TOOLS"

# 3. Expose ANDROID_HOME to interactive shells (idempotent) ------------------
BASHRC="$HOME/.bashrc"
MARKER="# >>> batak-ai android sdk >>>"
if ! grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
  echo "==> Adding Android SDK env to $BASHRC"
  {
    echo ""
    echo "$MARKER"
    echo "export ANDROID_HOME=\"$ANDROID_SDK_ROOT\""
    echo "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_ROOT\""
    echo "export PATH=\"\$PATH:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin\""
    echo "# <<< batak-ai android sdk <<<"
  } >> "$BASHRC"
fi

# 4. Project dependencies (only when a Gradle project exists) ----------------
if [ -x "/workspace/gradlew" ]; then
  echo "==> Warming Gradle dependencies"
  (cd /workspace && ANDROID_HOME="$ANDROID_SDK_ROOT" ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
    ./gradlew --no-daemon help >/dev/null) || true
fi

echo "==> Android SDK ready at $ANDROID_SDK_ROOT"
