#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 헤르메스 에이전트 — VPS(우분투) 가이드 설치 스크립트
#
# 공식 설치 스크립트를 "대체"하지 않습니다. 공식 스크립트를 받아서
# 저장소 원본과 대조한 뒤 실행하고, 앞뒤로 점검과 안내를 붙입니다.
#
# 사용법:
#   1) VPS에 SSH 접속:  ssh root@<VPS_IP>
#   2) bash install-vps.sh
# ---------------------------------------------------------------------------
set -euo pipefail

CDN_URL="https://hermes-agent.nousresearch.com/install.sh"
REPO_URL="https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"
TMP_CDN="$(mktemp -t hermes-cdn-XXXXXX.sh)"
TMP_REPO="$(mktemp -t hermes-repo-XXXXXX.sh)"
trap 'rm -f "$TMP_CDN" "$TMP_REPO"' EXIT

say()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$1"; }
note() { printf '  %s\n' "$1"; }
warn() { printf '  \033[33m⚠ %s\033[0m\n' "$1"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }
ask()  { local a; read -r -p "  $1 [y/N] " a; [ "${a:-N}" = "y" ] || [ "${a:-N}" = "Y" ]; }

echo "==========================================================="
echo "  헤르메스 에이전트 — VPS 설치"
echo "==========================================================="

# --- 0. 환경 확인 ----------------------------------------------------------
say "0단계 · 환경 확인"
[ "$(uname -s)" = "Linux" ] || die "리눅스(VPS) 전용입니다. macOS는 README 2-B, 윈도우는 2-C 를 보세요."
command -v curl >/dev/null 2>&1 || die "curl 이 없습니다:  apt-get update && apt-get install -y curl"

if [ "$(id -u)" = "0" ]; then
  note "root 로 실행 중입니다 (VPS에서는 정상)."
  note "설치 경로: /usr/local/lib/hermes-agent, 데이터: /root/.hermes"
else
  note "일반 사용자로 실행 중입니다."
  note "설치 경로: ~/.hermes/hermes-agent, 실행파일: ~/.local/bin/hermes"
  warn "sudo 를 붙이지 마세요. 붙이면 /usr/local/bin/hermes 가 진짜 설치를 가립니다."
fi

if [ -e /usr/local/bin/hermes ] && [ "$(id -u)" != "0" ]; then
  warn "/usr/local/bin/hermes 발견 — 과거 sudo 설치 흔적입니다."
  ask "제거할까요? (sudo rm /usr/local/bin/hermes)" && sudo rm -f /usr/local/bin/hermes
fi

# --- 1. 리눅스 사전 패키지 -------------------------------------------------
say "1단계 · 사전 패키지 (git / curl / xz-utils)"
note "리눅스에서 실제로 발목 잡는 건 파이썬이 아니라 xz-utils 입니다."
note "Node 를 .tar.xz 로 받아 푸는데, 없으면 설치가 깨집니다."
MISSING=""
command -v git >/dev/null 2>&1 || MISSING="$MISSING git"
{ command -v xz >/dev/null 2>&1 || command -v unxz >/dev/null 2>&1; } || MISSING="$MISSING xz-utils"
if [ -n "$MISSING" ]; then
  note "없는 패키지:$MISSING"
  if command -v apt-get >/dev/null 2>&1; then
    ask "지금 설치할까요? (apt-get install -y$MISSING)" && {
      if [ "$(id -u)" = "0" ]; then apt-get update && apt-get install -y $MISSING
      else sudo apt-get update && sudo apt-get install -y $MISSING; fi
    }
  else
    die "apt 계열이 아닙니다. 배포판 패키지 관리자로$MISSING 을 먼저 설치하세요."
  fi
else
  note "사전 패키지 모두 준비됨."
fi

# --- 2. 사전 점검 ----------------------------------------------------------
say "2단계 · 사전 점검"
PRE="$(dirname "$0")/preflight-check.sh"
if [ -f "$PRE" ]; then
  bash "$PRE" || true
  echo ""
  ask "위 점검 결과를 확인했습니다. 계속할까요?" || die "사용자가 중단했습니다."
else
  note "preflight-check.sh 를 찾지 못해 건너뜁니다."
fi

# --- 3. 설치 스크립트 받기 + 저장소 원본과 대조 ----------------------------
say "3단계 · 설치 스크립트 받기 · 원본 대조"
note "출처(배포): $CDN_URL"
if curl -fsSL "$CDN_URL" -o "$TMP_CDN" 2>/dev/null; then
  note "받았습니다 ($(wc -l < "$TMP_CDN") 줄)"
  SRC="$TMP_CDN"
else
  warn "배포 도메인 접속 실패. 저장소 직접 경로로 재시도합니다."
  curl -fsSL "$REPO_URL" -o "$TMP_CDN" || die "둘 다 실패했습니다. 네트워크/방화벽을 확인하세요."
  note "저장소에서 받았습니다 ($(wc -l < "$TMP_CDN") 줄)"
  SRC="$TMP_CDN"
fi

note "공개 저장소 사본과 대조합니다..."
if curl -fsSL "$REPO_URL" -o "$TMP_REPO" 2>/dev/null; then
  if diff -q "$TMP_CDN" "$TMP_REPO" >/dev/null 2>&1; then
    note "✅ 배포본과 저장소 사본이 동일합니다."
  else
    warn "배포본과 저장소 사본이 다릅니다."
    note "버전 차이일 수 있으나, 직접 확인하시길 권합니다."
    ask "차이를 보시겠습니까?" && diff "$TMP_REPO" "$TMP_CDN" | head -80 || true
    ask "그래도 계속할까요?" || die "사용자가 중단했습니다."
  fi
else
  warn "저장소 사본을 받지 못해 대조를 건너뜁니다."
fi

# --- 4. 실행 전 확인 -------------------------------------------------------
say "4단계 · 실행 전 확인"
note "원격 스크립트를 셸에 그대로 붓는 건 위험합니다. 내용을 확인하실 수 있습니다."
ask "스크립트 전문을 보시겠습니까?" && { ${PAGER:-less} "$SRC" || cat "$SRC"; }
echo ""
ask "설치를 진행할까요?" || die "사용자가 중단했습니다."

# --- 5. 설치 --------------------------------------------------------------
say "5단계 · 설치"
note "Python 3.11 / Node / ripgrep / ffmpeg / Git 을 받고 저장소를 클론합니다."
note "'2분' 은 마케팅 문구입니다. 실제로는 더 걸릴 수 있습니다. 끊지 마세요."
echo ""
if ask "설치 직후 셋업 마법사를 건너뛸까요? (나중에 hermes model 로 설정)"; then
  bash "$SRC" --skip-setup || die "설치 실패. 위 로그를 확인하세요."
else
  bash "$SRC" || die "설치 실패. 위 로그를 확인하세요."
fi

# --- 6. PATH 갱신 ---------------------------------------------------------
say "6단계 · 셸 환경 갱신"
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -f "$rc" ] && { set +u; . "$rc" >/dev/null 2>&1 || true; set -u; }
done
export PATH="$HOME/.local/bin:$PATH"

command -v hermes >/dev/null 2>&1 \
  || die "hermes 명령을 찾지 못했습니다. SSH를 끊고 다시 접속한 뒤 'hermes doctor' 를 실행하세요. (대개 PATH 문제이지 설치 실패가 아닙니다)"
note "설치 확인: $(hermes --version 2>&1 | head -n1)"

# --- 7. 진단 --------------------------------------------------------------
say "7단계 · 진단"
note "'hermes doctor' 는 과금되지 않습니다. '--live' 는 실제 API 호출을 하니 주의하세요."
hermes doctor || note "일부 항목 실패. 아래 안내를 참고하세요."

# --- 8. 다음 단계 ---------------------------------------------------------
cat <<'NEXT'

===========================================================
  설치 완료 — 셋팅 순서
===========================================================

  [1] 💰 비용 안전장치부터 (먼저 하세요)

      platform.claude.com → Settings → Billing
        · Spend limit 설정 (예: $50)
        · 선불 크레딧 $20만 충전, auto-reload 는 OFF
          ※ 신규 등급 기본 상한은 월 $500 입니다. 0원이 아닙니다.

      echo 'HERMES_MAX_ITERATIONS=30' >> ~/.hermes/.env
          ※ 기본값 500 입니다. 한 턴에 $37~75 가 날아갈 수 있습니다.

  [2] 모델 연결
      $ hermes model

      ❌ 메뉴에서 'Anthropic OAuth' / '클로드 계정 로그인' 을 고르지 마세요.
         앤트로픽 약관 위반이며, 사전 통보 없이 계정이 정지될 수 있습니다.
         --provider claude / claude-code 도 같은 경로의 별칭입니다.
      ✅ 'Anthropic (API key)' 를 고르고 platform.claude.com 키를 넣으세요.

      ⚠️ 모델을 직접 지정하세요. 안 하면 최고가 모델(claude-fable-5,
         $10/$50 per MTok)이 기본으로 걸립니다.
      $ hermes config set model.provider anthropic
      $ hermes config set model.default claude-sonnet-5
      $ chmod 600 ~/.hermes/.env

  [3] 동작 확인
      $ hermes

  [4] 슬랙 / 텔레그램 연동
      $ nano ~/.hermes/.env
      $ hermes gateway install && hermes gateway start
      $ sudo hermes gateway install --system     # 재부팅 후 자동 실행

      ⚠️ SLACK_ALLOWED_USERS / TELEGRAM_ALLOWED_USERS 를 반드시 채우세요.

  진단: hermes doctor    |    업데이트: hermes update
  설정 경로: hermes config path / hermes config env-path

===========================================================
NEXT
