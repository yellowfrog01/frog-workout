#!/bin/bash
# 수정 -> 빌드 -> 아이폰 + 애플워치 설치.
#   ./deploy.sh         아이폰만
#   ./deploy.sh watch   아이폰 + 워치
set -uo pipefail
# 기기·네트워크 식별값 로드 (deploy.env — 없으면 deploy.env.example 을 복사해서 작성)
ENV_FILE="$(cd "$(dirname "$0")" && pwd)/deploy.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "✗ deploy.env 가 없습니다. deploy.env.example 을 deploy.env 로 복사해서 본인 기기 값으로 채우세요." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"
PROJ="/Users/gimgeon/Documents/lab/apple-watch/WorkoutLog"
PHONE="$PHONE_UDID"
WATCH="$WATCH_ID"
cd "$PROJ"

echo "▸ 아이폰 빌드"
xcodebuild -project WorkoutLog.xcodeproj -scheme WorkoutLog -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath ./build-device \
  -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD" || true

if ! xcrun devicectl list devices 2>/dev/null | grep "$PHONE" | grep -qv "unavailable"; then
  echo "  ✗ 아이폰 연결 불가. Wi-Fi 확인."
  exit 1
fi
echo "▸ 아이폰 설치"
xcrun devicectl device install app --device "$PHONE" \
  ./build-device/Build/Products/Debug-iphoneos/WorkoutLog.app 2>&1 | grep -E "App installed|rror"
xcrun devicectl device process launch --device "$PHONE" com.gimgeon.WorkoutLog 2>&1 | grep -iE "Launched|rror"

if [ "${1:-}" = "watch" ]; then
  echo "▸ 워치 빌드"
  xcodebuild -project WorkoutLog.xcodeproj -scheme WatchApp -configuration Debug \
    -destination "platform=watchOS,id=$WATCH" -derivedDataPath ./build-watch \
    -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD|may need" || true
  echo "▸ 워치 설치"
  xcrun devicectl device install app --device "$WATCH" \
    ./build-watch/Build/Products/Debug-watchos/WatchApp.app 2>&1 | grep -E "App installed|rror|Recovery"
  echo "  (워치가 잠금 해제 + 맥과 같은 Wi-Fi 여야 함)"
fi
echo "✓ 완료"
