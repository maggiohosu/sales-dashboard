#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 헤르메스 에이전트 설치 전 사전 점검
#
# 목적: 설치를 시작했다가 중간에 실패해서 시스템이 어정쩡해지는 걸 막습니다.
#       특히 사내망(프록시/방화벽) 환경에서 뭐가 막혀 있는지 미리 확인합니다.
#
# 사용법:  bash preflight-check.sh
# 안전성:  읽기 전용입니다. 아무것도 설치/변경하지 않습니다.
# ---------------------------------------------------------------------------
set -uo pipefail

PASS=0; WARN=0; FAIL=0

ok()   { printf '  \033[32m[OK]\033[0m   %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  \033[33m[주의]\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31m[실패]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

echo "==========================================================="
echo "  헤르메스 에이전트 설치 전 점검"
echo "==========================================================="

# --- 1. 운영체제 -----------------------------------------------------------
head_ "1. 운영체제"
OS="$(uname -s 2>/dev/null || echo unknown)"
case "$OS" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      ok "WSL2 (윈도우 안의 리눅스) — 지원됩니다"
    else
      ok "Linux — 지원됩니다 (VPS 설치에 가장 적합)"
    fi
    if [ -r /etc/os-release ]; then
      . /etc/os-release
      echo "         배포판: ${PRETTY_NAME:-unknown}"
    fi
    ;;
  Darwin) ok "macOS — 지원됩니다" ;;
  *)      warn "확인되지 않은 OS ($OS) — 윈도우 네이티브라면 install.ps1 을 쓰세요" ;;
esac

# --- 2. 필수 도구 ----------------------------------------------------------
head_ "2. 필수 도구 (없으면 설치 스크립트가 자동으로 넣어줍니다)"
for t in curl git python3 node; do
  if command -v "$t" >/dev/null 2>&1; then
    v="$("$t" --version 2>&1 | head -n1)"
    ok "$t 있음 — $v"
  else
    warn "$t 없음 — 설치 스크립트가 자동 설치를 시도합니다"
  fi
done

# --- 3. 파이썬 버전 --------------------------------------------------------
head_ "3. 파이썬 버전 (헤르메스는 3.11 기준)"
if command -v python3 >/dev/null 2>&1; then
  PYV="$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo "?")"
  case "$PYV" in
    3.11|3.12|3.13) ok "Python $PYV — 문제 없습니다" ;;
    3.10|3.9)       warn "Python $PYV — 낮습니다. 설치 스크립트가 3.11을 따로 넣습니다" ;;
    *)              warn "Python $PYV — 확인 필요" ;;
  esac
else
  warn "python3 없음 — 설치 스크립트가 처리합니다"
fi

# --- 4. 네트워크 (사내망에서 가장 잘 막히는 부분) --------------------------
head_ "4. 네트워크 아웃바운드 — 사내망에서 가장 중요합니다"
check_url() {
  local name="$1" url="$2"
  if curl -fsS --max-time 12 -o /dev/null "$url" 2>/dev/null; then
    ok "$name 접속 가능"
  else
    bad "$name 접속 불가 — 사내 방화벽/프록시에 막혔을 수 있습니다"
  fi
}
check_url "GitHub"              "https://github.com"
check_url "PyPI (파이썬 패키지)" "https://pypi.org/simple/"
check_url "npm (노드 패키지)"    "https://registry.npmjs.org/"
check_url "헤르메스 배포 서버"    "https://hermes-agent.nousresearch.com"

# --- 5. 프록시 설정 --------------------------------------------------------
head_ "5. 프록시 환경변수"
if [ -n "${HTTPS_PROXY:-${https_proxy:-}}" ]; then
  warn "프록시가 설정되어 있습니다: ${HTTPS_PROXY:-$https_proxy}"
  echo "         → 사내망입니다. 설치 시 프록시를 그대로 유지해야 합니다."
else
  ok "프록시 없음 (일반 인터넷 직결)"
fi

# --- 6. 디스크 여유 --------------------------------------------------------
head_ "6. 디스크 여유 공간 (최소 5GB 권장)"
if command -v df >/dev/null 2>&1; then
  AVAIL_KB="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
  if [ -n "${AVAIL_KB:-}" ]; then
    AVAIL_GB=$(( AVAIL_KB / 1024 / 1024 ))
    if [ "$AVAIL_GB" -ge 5 ]; then ok "여유 공간 ${AVAIL_GB}GB"
    else bad "여유 공간 ${AVAIL_GB}GB — 부족합니다. 5GB 이상 확보하세요"; fi
  else
    warn "디스크 확인 실패"
  fi
fi

# --- 7. 기존 설치 여부 -----------------------------------------------------
head_ "7. 기존 헤르메스 설치 여부"
if command -v hermes >/dev/null 2>&1; then
  warn "이미 설치되어 있습니다 — $(hermes --version 2>&1 | head -n1)"
  echo "         → 재설치 대신 'hermes update' 를 쓰세요."
else
  ok "설치된 헤르메스 없음 (신규 설치)"
fi
[ -d "$HOME/.hermes" ] && warn "기존 설정 폴더 발견: ~/.hermes (설정이 남아 있습니다)"

# --- 결과 ------------------------------------------------------------------
echo ""
echo "==========================================================="
printf "  통과 %d건 / 주의 %d건 / 실패 %d건\n" "$PASS" "$WARN" "$FAIL"
echo "==========================================================="
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ 설치를 진행하셔도 됩니다."
  echo ""
  echo "     curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
else
  echo "  ❌ [실패] 항목을 먼저 해결하세요."
  echo ""
  echo "  네트워크가 막혀 있다면 선택지는 셋입니다:"
  echo "    1) VPS에 설치한다 (사내망과 무관해짐)  ← 가장 깔끔"
  echo "    2) 정보보안팀에 프록시 예외를 요청한다"
  echo "    3) 개인 네트워크(테더링)에서 설치 후 사내망에서 운영한다"
fi
echo ""
exit 0
