#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 헤르메스 에이전트 설치 전 점검
#
# 목적: 설치를 시작했다가 중간에 깨져서 시스템이 어정쩡해지는 걸 막습니다.
#       설치는 최소 9개 외부 호스트를 쓰기 때문에, 사내망에서는 하나만 막혀도
#       엉뚱한 단계에서 실패하고 원인 파악이 어렵습니다.
#
# 사용법:  bash preflight-check.sh
# 안전성:  읽기 전용입니다. 아무것도 설치/변경하지 않습니다.
# ---------------------------------------------------------------------------
set -uo pipefail

PASS=0; WARN=0; FAIL=0; BLOCK=0

ok()    { printf '  \033[32m[OK]\033[0m   %s\n' "$1"; PASS=$((PASS+1)); }
warn()  { printf '  \033[33m[주의]\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
bad()   { printf '  \033[31m[실패]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
block() { printf '  \033[1;41m[중단]\033[0m %s\n' "$1"; BLOCK=$((BLOCK+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

echo "==========================================================="
echo "  헤르메스 에이전트 설치 전 점검"
echo "==========================================================="

# --- 1. 운영체제 / 하드웨어 (하드 블로커 검사) -----------------------------
head_ "1. 운영체제 · 하드웨어"
OS="$(uname -s 2>/dev/null || echo unknown)"
ARCH="$(uname -m 2>/dev/null || echo unknown)"

case "$OS" in
  Darwin)
    if [ "$ARCH" = "arm64" ]; then
      ok "macOS (Apple Silicon, $ARCH) — 정식 지원"
      warn "설치 중 'xcode-select --install' 팝업이 뜹니다. 클릭하고 라이선스에 동의해야 진행됩니다."
      echo "         → 모르면 멈춘 줄 알고 강제 종료하게 됩니다. 주의하세요."
    else
      block "인텔 맥 ($ARCH) — 공식 미지원입니다. 설치하지 마세요."
      echo "         → Apple Silicon(M시리즈)만 지원됩니다. VPS 설치를 쓰세요."
    fi
    ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      ok "WSL2 (윈도우 안의 리눅스, $ARCH) — 지원됩니다"
    else
      ok "Linux ($ARCH) — 지원됩니다 (VPS 설치에 가장 적합)"
    fi
    case "$ARCH" in
      x86_64|aarch64|arm64) : ;;
      *) block "지원되지 않는 아키텍처 ($ARCH)" ;;
    esac
    [ -r /etc/os-release ] && { . /etc/os-release; echo "         배포판: ${PRETTY_NAME:-unknown}"; }
    ;;
  *)
    warn "확인되지 않은 OS ($OS) — 윈도우 네이티브라면 install.ps1 을 쓰세요"
    ;;
esac

if [ "$(id -u)" = "0" ] && [ "$OS" != "Linux" ]; then
  warn "root 로 실행 중입니다."
elif [ "$(id -u)" = "0" ]; then
  warn "root 로 실행 중입니다. VPS라면 정상이지만, 개인 PC라면 일반 사용자로 설치하세요."
  echo "         → sudo 설치는 /usr/local/bin/hermes 를 만들어 진짜 설치를 가립니다."
fi

# --- 2. 필수 도구 ----------------------------------------------------------
head_ "2. 필수 도구"
command -v git >/dev/null 2>&1 \
  && ok "git 있음 — $(git --version 2>&1 | head -n1)" \
  || bad "git 없음 — 유일한 필수 사전 요구사항입니다. 먼저 설치하세요."

command -v curl >/dev/null 2>&1 \
  && ok "curl 있음" \
  || bad "curl 없음 — 설치 스크립트를 받을 수 없습니다."

if [ "$OS" = "Linux" ]; then
  if command -v xz >/dev/null 2>&1 || command -v unxz >/dev/null 2>&1; then
    ok "xz-utils 있음"
  else
    bad "xz-utils 없음 — Node를 .tar.xz 로 받아 푸는데 실패합니다."
    echo "         → sudo apt install -y xz-utils"
  fi
fi

# --- 3. 파이썬 / 노드 버전 (함정 검사) -------------------------------------
head_ "3. 파이썬 · 노드 버전"
if command -v python3 >/dev/null 2>&1; then
  PYV="$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo "?")"
  case "$PYV" in
    3.14|3.15) block "Python $PYV — 설치가 실패합니다 (pydantic-core 휠 없음). 3.11~3.13 이 필요합니다." ;;
    3.11|3.12|3.13) ok "Python $PYV — 문제 없습니다" ;;
    *) warn "Python $PYV — 설치 스크립트가 자체 Python 3.11 을 넣습니다" ;;
  esac
else
  ok "python3 없음 — 설치 스크립트가 자체 Python 3.11 을 넣습니다"
fi

if [ -n "${UV_PYTHON:-}" ]; then
  warn "UV_PYTHON 환경변수가 설정돼 있습니다: $UV_PYTHON"
  echo "         → 3.14 로 잡혀 있으면 설치가 실패합니다. unset UV_PYTHON 후 재시도하세요."
fi

if command -v node >/dev/null 2>&1; then
  NODEV="$(node --version 2>/dev/null | sed 's/^v//')"
  NMAJ="${NODEV%%.*}"; NREST="${NODEV#*.}"; NMIN="${NREST%%.*}"
  case "$NMAJ" in
    22) [ "${NMIN:-0}" -ge 22 ] && ok "Node v$NODEV — 통과" || warn "Node v$NODEV — 22.22 미만. 자체 Node를 따로 받습니다." ;;
    24) [ "${NMIN:-0}" -ge 11 ] && ok "Node v$NODEV — 통과" || warn "Node v$NODEV — 24.11 미만. 자체 Node를 따로 받습니다." ;;
    23|25) warn "Node v$NODEV — 명시적으로 거부되는 버전입니다. 자체 Node를 따로 받습니다." ;;
    *) if [ "${NMAJ:-0}" -ge 26 ]; then ok "Node v$NODEV — 통과"; else warn "Node v$NODEV — 자체 Node를 따로 받습니다."; fi ;;
  esac
else
  ok "node 없음 — 설치 스크립트가 자체 Node 를 넣습니다"
fi

# --- 4. 네트워크 (설치가 쓰는 9개 호스트 전부) -----------------------------
head_ "4. 네트워크 아웃바운드 — 설치가 쓰는 호스트 전부"
echo "  (하나만 막혀도 설치가 엉뚱한 단계에서 깨집니다)"
NET_FAIL=0
check_url() {
  local name="$1" url="$2"
  if curl -fsS --max-time 12 -o /dev/null "$url" 2>/dev/null; then
    ok "$name"
  else
    bad "$name — 차단됨"
    NET_FAIL=$((NET_FAIL+1))
  fi
}
check_url "github.com (저장소 클론)"        "https://github.com"
check_url "raw.githubusercontent.com"       "https://raw.githubusercontent.com"
check_url "pypi.org (파이썬 패키지)"         "https://pypi.org/simple/"
check_url "registry.npmjs.org (노드 패키지)" "https://registry.npmjs.org/"
check_url "nodejs.org (Node 런타임)"         "https://nodejs.org"
check_url "astral.sh (uv 설치기)"            "https://astral.sh"
check_url "git-scm.com (PortableGit)"        "https://git-scm.com"
check_url "hermes-agent.nousresearch.com"    "https://hermes-agent.nousresearch.com"

# --- 5. 프록시 / TLS 가로채기 ---------------------------------------------
head_ "5. 프록시 · TLS 가로채기"
if [ -n "${HTTPS_PROXY:-${https_proxy:-}}" ]; then
  warn "프록시 설정됨: ${HTTPS_PROXY:-$https_proxy}"
  echo "         → 사내망입니다. 설치 중 'unable to get local issuer certificate' 가 뜨면"
  echo "           권한 문제가 아니라 TLS 가로채기입니다. 정보보안팀에 사내 CA 등록을 요청하세요."
  echo "         → 호스트 설치에는 프록시/CA를 설정하는 공식 지원 방법이 없습니다."
else
  ok "프록시 없음 (일반 인터넷 직결)"
fi

# --- 6. 디스크 -------------------------------------------------------------
head_ "6. 디스크 여유 공간 (최소 5GB 권장)"
AVAIL_KB="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
if [ -n "${AVAIL_KB:-}" ]; then
  AVAIL_GB=$(( AVAIL_KB / 1024 / 1024 ))
  [ "$AVAIL_GB" -ge 5 ] && ok "여유 ${AVAIL_GB}GB" || bad "여유 ${AVAIL_GB}GB — 부족합니다"
else
  warn "디스크 확인 실패"
fi

# --- 7. 기존 설치 ----------------------------------------------------------
head_ "7. 기존 설치 여부"
if command -v hermes >/dev/null 2>&1; then
  warn "이미 설치돼 있습니다 — $(hermes --version 2>&1 | head -n1)"
  echo "         → 재설치 대신 'hermes update' 를 쓰세요."
else
  ok "설치된 헤르메스 없음 (신규 설치)"
fi
[ -e /usr/local/bin/hermes ] && bad "/usr/local/bin/hermes 발견 — 과거 sudo 설치 흔적입니다. 진짜 설치를 가립니다." \
  && echo "         → sudo rm /usr/local/bin/hermes"
[ -d "$HOME/.hermes" ] && warn "기존 설정 폴더 발견: ~/.hermes"

# --- 8. 계정 연결 경고 -----------------------------------------------------
head_ "8. ⚠️ 설치 후 주의 (지금 확인할 수는 없지만 반드시 알아야 할 것)"
printf "  · 'hermes model' 메뉴의 Anthropic OAuth / 클로드 계정 로그인 → \033[1;31m절대 고르지 마세요\033[0m\n"
echo "    앤트로픽 약관 위반이며, 사전 통보 없이 계정 정지될 수 있습니다."
echo "  · --provider claude / --provider claude-code 는 anthropic 의 별칭입니다. 같은 함정입니다."
echo "  · 반드시 model.default 를 직접 지정하세요. 안 하면 최고가 모델(fable-5)이 걸립니다."
echo "  · HERMES_MAX_ITERATIONS=30 을 .env 에 넣으세요. 기본값 500 은 한 턴에 \$37~75 를 태웁니다."
echo "  · platform.claude.com 에서 지출 한도를 먼저 걸고 선불 크레딧만 충전하세요 (auto-reload OFF)."

# --- 결과 ------------------------------------------------------------------
echo ""
echo "==========================================================="
printf "  통과 %d / 주의 %d / 실패 %d / 중단 %d\n" "$PASS" "$WARN" "$FAIL" "$BLOCK"
echo "==========================================================="
if [ "$BLOCK" -gt 0 ]; then
  echo "  ⛔ [중단] 항목이 있습니다. 이 환경에서는 설치할 수 없습니다."
  echo "     → VPS 설치를 쓰세요."
elif [ "$FAIL" -eq 0 ]; then
  echo "  ✅ 설치를 진행하셔도 됩니다."
  echo ""
  echo "     curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
else
  echo "  ❌ [실패] 항목을 먼저 해결하세요."
  if [ "$NET_FAIL" -gt 0 ]; then
    echo ""
    echo "  네트워크가 ${NET_FAIL}개 막혀 있습니다. 선택지는 셋입니다:"
    echo "    1) VPS에 설치한다 (사내망과 무관해짐)  ← 가장 깔끔"
    echo "    2) 정보보안팀에 위 호스트 허용을 요청한다"
    echo "    3) 배포 도메인만 막혔다면 저장소 직접 경로를 쓴다:"
    echo "       curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
  fi
fi
echo ""
exit 0
