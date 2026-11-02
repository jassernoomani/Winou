#!/usr/bin/env bash
# The Jenkinsfile's APK stage: builds the release APK against the live server and publishes it at
# https://<domain>/download/winou.apk (the folder Caddy serves, in the laptop's copy of the repo).
set -euo pipefail

repo="${WINOU_HOST_REPO:?WINOU_HOST_REPO is not set}"

# The Android SDK lives in the jenkins_home volume; Gradle downloads what it needs once licences
# are accepted.
mkdir -p "$ANDROID_HOME"
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null || true

# The Flutter template gives Gradle 8 GB (mobile/android/gradle.properties); here it shares the
# laptop with the live server. Gradle reads these user-level settings over the project's.
# Metaspace: the Kotlin compiler runs inside Gradle (in-process) and needs more than 512 MB.
# Out of memory, Gradle stops at once instead of hanging until the stage times out.
mkdir -p "$HOME/.gradle"
cat > "$HOME/.gradle/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=1g -XX:+ExitOnOutOfMemoryError
org.gradle.daemon=false
kotlin.compiler.execution.strategy=in-process
EOF

# The laptop's debug key signs the APK (as in deploy/README.md), so installed apps update in place
mkdir -p "$HOME/.android"
cp /run/secrets/android-debug.keystore "$HOME/.android/debug.keystore"

cd mobile
# Firebase app config is kept out of git; take the laptop's copy
cp "$repo/mobile/android/app/google-services.json" android/app/google-services.json

flutter pub get
flutter build apk --release --target-platform android-arm64 --dart-define=API_URL="https://${WINOU_DOMAIN}"

cp build/app/outputs/flutter-apk/app-release.apk "$repo/deploy/download/winou.apk"
echo "Published https://${WINOU_DOMAIN}/download/winou.apk"
