#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MOBILE_DIR="$PROJECT_DIR/mobile"

echo "== CHECKTAP OFFLINE 5: REINTENTOS Y SEGUNDO PLANO =="
grep -q "workmanager:" "$MOBILE_DIR/pubspec.yaml"
grep -q "connectivity_plus:" "$MOBILE_DIR/pubspec.yaml"
grep -q "registerPeriodicTask" "$MOBILE_DIR/lib/services/background_sync.dart"
grep -q "registerOneOffTask" "$MOBILE_DIR/lib/services/background_sync.dart"
grep -q "UIBackgroundModes" "$MOBILE_DIR/ios/Runner/Info.plist"
grep -q "registerLaunchHandlers" "$MOBILE_DIR/ios/Runner/AppDelegate.swift"
grep -q "setPluginRegistrantCallback" "$MOBILE_DIR/ios/Runner/AppDelegate.swift"
grep -q "minSdk = 23" "$MOBILE_DIR/android/app/build.gradle.kts"

if command -v flutter >/dev/null 2>&1; then
  cd "$MOBILE_DIR"
  flutter pub get
  flutter analyze
fi

if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  echo "Dispositivo Android detectado. Trabajos programados de CheckTap:"
  adb shell dumpsys jobscheduler 2>/dev/null | grep -A 8 -B 2 com.sistemasnorte.checktap || true
else
  echo "AVISO: no hay dispositivo ADB; se omitio la inspeccion de WorkManager."
fi

echo "RESULTADO: OFFLINE 5 APROBADO ESTRUCTURALMENTE"
