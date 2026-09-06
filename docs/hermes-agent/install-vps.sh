#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 헤르메스 에이전트 — VPS(우분투) 가이드 설치 스크립트
#
# 이 스크립트는 공식 설치 스크립트를 "대체"하지 않습니다.
# 공식 스크립트를 안전하게 실행하도록 감싸고, 앞뒤로 점검과 안내를 붙입니다.
#
# 사용법:
#   1) VPS에 SSH 접속:  ssh root@<VPS_IP>
#   2) 이 파일을 올리거나 내용을 붙여넣고:  bash install-vps.sh
# ---------------------------------------------------------------------------
set -euo pipefail

INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
TMP_SCRIPT="$(mktemp -t hermes-install-XXXXXX.sh)"
trap 'rm -f "$TMP_SCRIPT"' EXIT

say()  { printf '\n\033[1;36m▶ %s\033[0m\n' "$1"; }
note() { printf '  %s\n' "$1"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

echo "==========================================================="
echo "  헤르메스 에이전트 — VPS 설치"
echo "==========================================================="

# --- 0. 사전 점검 ----------------------------------------------------------
say "0단계 · 사전 점검"
[ "$(uname -s)" = "Linux" ] || die "이 스크립트는 리눅스(VPS) 전용입니다. macOS는 README의 2-B를, 윈도우는 2-C를 보세요."
command -v curl >/dev/null 2>&1 || die "curl 이 없습니다.  apt-get update && apt-get install -y curl  먼저 실행하세요."

if [ -f "$(dirname "$0")/preflight-check.sh" ]; then
  note "preflight-check.sh 를 함께 돌립니다..."
  bash "$(dirname "$0")/preflight-check.sh" || true
  echo ""
  read -r -p "  위 점검 결과를 확인했습니다. 계속할까요? [y/N] " ans
  [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ] || die "사용자가 중단했습니다."
fi

# --- 1. 공식 설치 스크립트 내려받기 ----------------------------------------
say "1단계 · 공식 설치 스크립트 내려받기"
note "출처: $INSTALL_URL"
curl -fsSL "$INSTALL_URL" -o "$TMP_SCRIPT" \
  || die "다운로드 실패. 네트워크 또는 방화벽을 확인하세요."
note "받았습니다 ($(wc -l < "$TMP_SCRIPT") 줄, $(wc -c < "$TMP_SCRIPT") 바이트)"

# --- 2. 실행 전 내용 확인 (보안) -------------------------------------------
say "2단계 · 실행 전 내용 확인"
note "원격 스크립트를 그대로 실행하는 건 위험합니다. 먼저 내용을 확인하세요."
echo ""
read -r -p "  스크립트 전문을 보시겠습니까? [y/N] " show
if [ "${show:-N}" = "y" ] || [ "${show:-N}" = "Y" ]; then
  ${PAGER:-less} "$TMP_SCRIPT" || cat "$TMP_SCRIPT"
fi
echo ""
read -r -p "  설치를 진행할까요? [y/N] " go
[ "${go:-N}" = "y" ] || [ "${go:-N}" = "Y" ] || die "사용자가 중단했습니다."

# --- 3. 설치 --------------------------------------------------------------
say "3단계 · 설치 (Python 3.11 / Node.js / ripgrep / ffmpeg / Git 자동 설치)"
note "몇 분 걸립니다. 중간에 끊지 마세요."
bash "$TMP_SCRIPT" || die "설치 스크립트가 실패했습니다. 위 로그를 확인하세요."

# --- 4. PATH 갱신 ---------------------------------------------------------
say "4단계 · 셸 환경 갱신"
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  [ -f "$rc" ] && { note "source $rc"; set +u; . "$rc" >/dev/null 2>&1 || true; set -u; }
done

command -v hermes >/dev/null 2>&1 \
  || die "hermes 명령을 찾지 못했습니다. SSH를 끊고 다시 접속한 뒤 'hermes doctor' 를 실행해보세요."
note "설치 확인: $(hermes --version 2>&1 | head -n1)"

# --- 5. 진단 --------------------------------------------------------------
say "5단계 · 설치 진단 (hermes doctor)"
hermes doctor || note "일부 항목이 실패했습니다. 아래 안내를 참고하세요."

# --- 6. 다음 단계 안내 ----------------------------------------------------
cat <<'NEXT'

===========================================================
  설치 완료 — 이제 아래 순서로 셋팅하세요
===========================================================

  [1] 모델 연결 (API 키 입력)
      $ hermes model

      ⚠️  클로드 Pro/Max 구독 계정은 연결할 수 없습니다.
          2026년 4월 4일부로 앤트로픽이 서드파티 도구에서의
          구독 OAuth 사용을 금지했습니다.
          → OpenRouter 또는 Anthropic API 키(종량제)를 쓰세요.

      💰 반드시 API 콘솔에서 '지출 한도'를 먼저 걸어두세요.
          첫 달은 $20 이하 권장.

  [2] 동작 확인
      $ hermes

  [3] 슬랙/텔레그램 연동
      $ nano ~/.hermes/.env        # 토큰 입력
      $ hermes gateway install
      $ hermes gateway start

      재부팅 후에도 자동 실행:
      $ sudo hermes gateway install --system

      ⚠️  SLACK_ALLOWED_USERS / TELEGRAM_ALLOWED_USERS 를
          비워두지 마세요. 아무나 에이전트를 조종하게 됩니다.

  [4] 설정 파일 위치
      $ hermes config path         # config.yaml
      $ hermes config env-path     # .env (비밀키는 여기에만)

  문제가 생기면:  hermes doctor
  업데이트:       hermes update

===========================================================
NEXT
