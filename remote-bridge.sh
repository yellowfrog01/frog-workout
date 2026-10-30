#!/bin/bash
# iPhone 원격 배포 브리지 — Bonjour 스푸핑 + Tailscale 릴레이
#
#   ./remote-bridge.sh capture  (집, 폰이 같은 Wi-Fi 일 때) 폰의 현재 광고값을 저장 — 나가기 직전에 실행
#   ./remote-bridge.sh probe    폰이 tailnet 너머로 도달 가능한지 검사
#   ./remote-bridge.sh bridge   저장된 값으로 가짜 Bonjour 레코드 등록 + socat 릴레이 상주
#   ./remote-bridge.sh deploy   (bridge 가동 중) 설치 + 실행. 터널 릴레이를 자동으로 맞춘다
#   ./remote-bridge.sh stop     브리지·릴레이 전부 종료
#   ./remote-bridge.sh status   현재 상태 점검
#
# 2026-09-17 헬스장에서 실제 성공한 구조 (sudo 불필요):
#   - 기기 발견: 가짜 Bonjour 레코드가 맥 en0 주소를 폰으로 광고
#   - 페어링 TCP ($PAIR_PORT): 맥 → 폰, socat 릴레이
#   - 터널 TCP+TLS: 맥 → "광고된 주소:포트". 포트는 폰이 매 시도마다 정하는데 1씩 증가한다
#     (64072 → 64073 → 64074 …). remotepairingd 로그의 "Got tunnel endpoint" 에서 마지막 포트를 읽어
#     그 다음 포트들에 릴레이를 미리 띄운 뒤 재시도하면 붙는다.

set -uo pipefail

# 기기·네트워크 식별값 로드 (deploy.env — 없으면 deploy.env.example 을 복사해서 작성)
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "✗ deploy.env 가 없습니다. deploy.env.example 을 deploy.env 로 복사해서 본인 기기 값으로 채우세요." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

# 폰의 광고값(identifier·authTag·포트)은 바뀐다 (9/13 → 9/17 에 셋 다 바뀜).
# capture 로 저장한 값을 쓴다.
CACHE="$(dirname "$0")/.remote-bridge.cache"
PHONE_IP="${PHONE_IP:-$PHONE_TAILNET_IP}"
DEVICE_UDID="$PHONE_COREDEVICE_ID"
TS="/opt/homebrew/bin/tailscale --socket=/var/run/tailscaled.socket"

log() { printf '\033[36m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
err() { printf '\033[31m[!]\033[0m %s\n' "$*" >&2; }

phone_ip() { echo "$PHONE_IP"; }

# 맥의 LAN 주소. Wi-Fi(en0)가 꺼져 있고 유선(USB LAN 등)일 수도 있어 기본 경로 인터페이스를 쓴다.
# 강제하려면 BRIDGE_IF=en0 처럼 지정.
lan_ip() {
  local ifc="${BRIDGE_IF:-$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')}"
  ipconfig getifaddr "${ifc:-en0}"
}

# macOS 에는 timeout 이 없다
with_timeout() { local t=$1; shift; perl -e 'alarm shift; exec @ARGV' "$t" "$@"; }

load_cache() {
  [[ -f "$CACHE" ]] || { err "저장된 광고값 없음 — 집에서 './remote-bridge.sh capture' 먼저"; exit 1; }
  # shellcheck disable=SC1090
  source "$CACHE"
  log "저장값: id=$INSTANCE port=$PAIR_PORT (저장 $CAPTURED_AT)"
}

cmd_capture() {
  log "폰의 _remotepairing 광고 찾는 중 (폰이 이 맥과 같은 Wi-Fi 여야 함)"
  local line inst
  line=$(with_timeout 5 dns-sd -B _remotepairing._tcp local. 2>/dev/null | grep -a " Add " | head -1)
  inst=$(awk '{print $NF}' <<<"$line")
  [[ -z "$inst" ]] && { err "광고를 못 찾음 — 폰 Wi-Fi 확인"; exit 1; }
  local res
  res=$(with_timeout 5 dns-sd -L "$inst" _remotepairing._tcp local. 2>/dev/null)
  local host port tag
  host=$(grep -ao 'reached at [^:]*' <<<"$res" | head -1 | sed 's/reached at //; s/\.$//')
  port=$(grep -ao 'reached at [^ ]*' <<<"$res" | head -1 | sed 's/.*://')
  tag=$(grep -ao 'authTag=[^ ]*' <<<"$res" | head -1 | cut -d= -f2)
  [[ "$host" != "$PHONE_HOST" ]] && { err "다른 기기의 광고: $host (기대: $PHONE_HOST)"; exit 1; }
  [[ -z "$port" || -z "$tag" ]] && { err "해석 실패:\n$res"; exit 1; }
  cat > "$CACHE" <<EOF
INSTANCE="$inst"
AUTHTAG="$tag"
PAIR_PORT=$port
CAPTURED_AT="$(date '+%Y-%m-%d %H:%M')"
EOF
  log "저장: id=$inst authTag=$tag port=$port → $CACHE"
}

cmd_status() {
  log "Tailscale 데몬"
  $TS status >/dev/null 2>&1 && echo "  OK" || { err "  미실행 — 'sudo tailscaled install-system-daemon' 또는 App Store 앱 필요"; }
  log "폰 tailnet 주소"
  local ip; ip=$(phone_ip)
  [[ -n "$ip" ]] && echo "  $ip" || err "  탐색 실패 — 폰에 Tailscale 로그인 확인"
  log "Wi-Fi 인터페이스 광고 여부 (en0에 떠야 무선 연결 활성)"
  with_timeout 4 dns-sd -B _remotepairing._tcp local. 2>/dev/null | tail -n +4 || true
  log "devicectl"
  with_timeout 15 xcrun devicectl list devices 2>&1 | tail -n +2
  log "저장된 광고값"
  [[ -f "$CACHE" ]] && sed 's/^/  /' "$CACHE" || echo "  없음"
  log "서브넷 라우트"
  /opt/homebrew/bin/tailscale status --json 2>/dev/null | grep -A2 '"PrimaryRoutes"' | tr -d ' \n'; echo
}

cmd_probe() {
  local ip; ip=$(phone_ip)
  if [[ -z "$ip" ]]; then err "폰 tailnet IP를 못 찾음"; exit 1; fi
  log "폰 tailnet IP: $ip"
  load_cache

  log "ping (tailnet 도달성)"
  if $TS ping --c 3 --timeout 3s "$ip" 2>&1 | tail -2; then :; fi

  log "RemotePairing 포트 $PAIR_PORT 검사"
  if nc -z -G 5 "$ip" "$PAIR_PORT" 2>/dev/null; then
    printf '\033[32m  OPEN — 이 네트워크 상태에서 브리지 가능\033[0m\n'
  else
    printf '\033[31m  CLOSED — 리스너가 바인드되지 않음\033[0m\n'
  fi

}

cmd_bridge() {
  local ip; ip=$(phone_ip)
  [[ -z "$ip" ]] && { err "폰 tailnet IP를 못 찾음"; exit 1; }
  local en0; en0=$(lan_ip)
  [[ -z "$en0" ]] && { err "LAN 주소 없음 (맥이 네트워크에 연결돼 있어야 함)"; exit 1; }

  load_cache
  log "폰=$ip  맥en0=$en0"
  trap 'log "정리 중..."; kill 0 2>/dev/null' EXIT INT TERM

  # 터널(UDP 3722)은 폰→맥 방향이라 릴레이하지 않는다. 서브넷 라우트가 담당.
  log "socat: $en0:$PAIR_PORT -> $ip:$PAIR_PORT"
  socat TCP-LISTEN:$PAIR_PORT,reuseaddr,fork,bind=$en0 TCP:$ip:$PAIR_PORT &

  sleep 1
  log "가짜 Bonjour 레코드 등록 (맥 en0을 가리킴)"
  dns-sd -P "$INSTANCE" _remotepairing._tcp local. "$PAIR_PORT" \
    "$PHONE_HOST" "$en0" \
    identifier="$INSTANCE" authTag="$AUTHTAG" ver=24 minVer=8 flags=0 &

  log "브리지 가동. Ctrl+C 로 종료."
  wait
}

APP="$(dirname "$0")/WorkoutLog/build-device/Build/Products/Debug-iphoneos/WorkoutLog.app"
BUNDLE="com.gimgeon.WorkoutLog"
RELAY_SPAN=30

last_tunnel_port() {
  /usr/bin/log show --last 30m --style compact \
    --predicate 'process == "remotepairingd" && eventMessage CONTAINS "Got tunnel endpoint"' 2>/dev/null \
    | grep -o "endpoint: '[^']*'" | tail -1 | sed "s/.*[:.]//; s/'//"   # 'addr%en0:port' 또는 'addr%en0.port'
}

# 포트 p+1 .. p+RELAY_SPAN 에 릴레이가 없으면 띄운다 (이미 떠 있으면 건너뜀)
ensure_tunnel_relays() {
  local base=$1 ip en0 n=0
  ip=$(phone_ip); en0=$(lan_ip)
  for p in $(seq $((base + 1)) $((base + RELAY_SPAN))); do
    lsof -nP -iTCP@"$en0":"$p" -sTCP:LISTEN >/dev/null 2>&1 && continue
    nohup socat TCP4-LISTEN:"$p",bind="$en0",reuseaddr,fork TCP4:"$ip":"$p" >/dev/null 2>&1 &
    disown; n=$((n + 1))
  done
  log "터널 릴레이 $((base + 1))..$((base + RELAY_SPAN)) (새로 띄움 $n개)"
}

try_install() {
  xcrun devicectl device install app --device "$DEVICE_UDID" "$APP" 2>&1 | grep -qE "databaseUUID|App installed"
}

cmd_deploy() {
  [[ -d "$APP" ]] || { err "빌드 산출물 없음: $APP"; exit 1; }
  local port; port=$(last_tunnel_port)
  [[ -n "$port" ]] && ensure_tunnel_relays "$port"
  log "설치 시도"
  if ! try_install; then
    port=$(last_tunnel_port)
    [[ -z "$port" ]] && { err "터널 포트를 로그에서 못 찾음 — bridge 가동 여부 확인"; exit 1; }
    log "터널 포트 $port 에서 실패 → 다음 포트들에 릴레이"
    ensure_tunnel_relays "$port"
    log "재시도"
    try_install || { err "설치 실패 (마지막 터널 포트: $(last_tunnel_port))"; exit 1; }
  fi
  log "설치 완료 → 실행"
  xcrun devicectl device process launch --device "$DEVICE_UDID" --terminate-existing "$BUNDLE" 2>&1 | tail -1
}

cmd_stop() {
  pkill -f "socat TCP4-LISTEN:6" 2>/dev/null
  pkill -f "socat TCP-LISTEN:$(source "$CACHE" 2>/dev/null; echo "${PAIR_PORT:-x}")" 2>/dev/null
  pkill -f "dns-sd -P" 2>/dev/null
  pkill -f "remote-bridge.sh bridge" 2>/dev/null
  log "브리지·릴레이 종료"
}

case "${1:-status}" in
  capture) cmd_capture ;;
  deploy) cmd_deploy ;;
  stop)   cmd_stop ;;
  probe)  cmd_probe ;;
  bridge) cmd_bridge ;;
  status) cmd_status ;;
  *) echo "usage: $0 {capture|probe|bridge|deploy|stop|status}"; exit 1 ;;
esac
