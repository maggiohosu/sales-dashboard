# 헤르메스 에이전트(Hermes Agent) 설치 · 셋팅 가이드

> 대상: 개발자가 아닌 실무자 (온라인 MD / 유통 벤더 기준)
> 참고 영상: [헤르메스 에이전트 처음 써보는 분도 이 영상 하나로 끝납니다](https://youtu.be/j5CIK1pcf3A) — 빌더 조쉬, 2026-05-29, 39분
> 원본 저장소: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)

---

## 0. 시작 전 반드시 알아야 할 3가지

### ⚠️ (1) 클로드 구독 계정은 헤르메스에 연결할 수 없습니다

**2026년 4월 4일부로 앤트로픽이 공식 금지했습니다.**

> "The use of OAuth tokens obtained via Claude Free, Pro, or Max accounts
> in any other product, tool, or service is not permitted."

OAuth(구독 로그인) 인증은 **Claude Code와 Claude.ai 전용**입니다.
헤르메스 같은 서드파티 하네스에서 구독 계정을 쓰면 **약관 위반 + 계정 정지 리스크**입니다.

→ **결론: 지금 내고 계신 Claude Pro/Max 구독료는 헤르메스에 1원도 적용되지 않습니다.**
→ 별도의 **종량제 API 비용**이 추가로 발생합니다. 예산 항목이 하나 늘어납니다.

### ⚠️ (2) 영상 설명의 "Codex OAuth 패치" 링크는 OAuth 우회가 아닙니다

영상 설명란의 [issues/32883](https://github.com/NousResearch/hermes-agent/issues/32883) 을 직접 확인한 결과,
이 이슈는 **OAuth 우회 패치가 아니라 버그 픽스**입니다.

- 실제 내용: OpenAI Codex Responses API 연동 시 발생하는
  `TypeError: 'NoneType' object is not iterable` 크래시 수정
- 수정 파일: `agent/codex_responses_adapter.py`, `agent/codex_runtime.py`, `agent/conversation_loop.py`
- **OAuth, 약관 우회, 서드파티 인증에 대한 언급은 이슈 본문에 없습니다.**

혹시 "구독으로 공짜로 돌리는 법"을 기대하셨다면, 그 경로는 막혔다고 보시는 게 안전합니다.

### ⚠️ (3) 영상은 VPS(호스팅어) 설치 방식입니다 — 내 PC 설치가 아닙니다

영상은 **월 1만원대 Hostinger VPS**에 설치하는 방식을 다룹니다.
영상 설명의 호스팅어 링크(`JOSH10` 할인코드)는 **제휴(affiliate) 링크**입니다.
제품이 나쁘다는 뜻은 아니지만, 추천에 수익이 걸려 있다는 점은 감안하고 보세요.

**VPS를 쓰는 이유는 타당합니다:**

| 항목 | 내 PC 설치 | VPS 설치 |
|---|---|---|
| 24시간 구동 | ❌ PC 꺼지면 중단 | ✅ 항상 켜짐 |
| 예약 작업(아침 브리핑 등) | ❌ 불안정 | ✅ 안정적 |
| 모바일에서 접근 | ❌ 어려움 | ✅ 슬랙/텔레그램으로 |
| 사내 보안 정책 | ⚠️ 충돌 가능 | ✅ 무관 |
| 비용 | 0원 | 월 1~2만원 |

**MD 업무(아침 브리핑, 재고 알림, 리포트 자동화) 목적이라면 VPS가 맞습니다.**

---

## 1. 어떤 모델로 돌릴지 먼저 정하기

헤르메스는 모델 종속이 없습니다. 아래 중 하나를 고르세요.

| 경로 | 인증 | 비용 감각 | 약관 | 추천도 |
|---|---|---|---|---|
| **OpenRouter** | `OPENROUTER_API_KEY` | 종량제, 모델 갈아타기 자유 | ✅ | ⭐ **입문 추천** |
| **Anthropic API 직접** | `ANTHROPIC_API_KEY` | 종량제, 클로드 전용 | ✅ | 클로드만 쓸 때 |
| **Nous Portal** | 포털 구독 | 통합 구독 | ✅ | 여러 툴 묶어 쓸 때 |
| **로컬 Ollama** | 불필요 | 무료 (PC 사양 필요) | ✅ | 사양 좋을 때 |
| ~~클로드 구독 OAuth~~ | ~~로그인~~ | ~~구독 포함~~ | ❌ **금지** | 사용 불가 |

> **입문자에게 OpenRouter를 권하는 이유**
> 저장소의 `.env.example`에도 `ANTHROPIC_API_KEY`는 아예 없고 `OPENROUTER_API_KEY`가 기본입니다.
> 키 하나로 클로드·GPT·제미나이를 전부 쓸 수 있어서, 모델별로 키를 따로 발급받을 필요가 없습니다.
> 비싸다 싶으면 `hermes model` 한 줄로 저렴한 모델로 갈아탈 수 있습니다.

**💰 비용 사고 사고 방지 (필수)**
어떤 경로든 **선불 크레딧 + 지출 한도(spend limit)** 를 반드시 먼저 걸어두세요.
에이전트는 루프에 빠지면 토큰을 순식간에 태웁니다. 첫 달은 **$20 이하**로 묶어놓고 감을 잡으세요.

---

## 2. 설치

### 2-A. VPS(우분투) — 영상 방식 · 권장

VPS 생성 후 SSH로 접속한 다음, 이 저장소의 `install-vps.sh` 내용을 붙여넣고 실행하세요.

```bash
# 1) VPS에 SSH 접속
ssh root@<VPS_IP주소>

# 2) 헤르메스 설치 (공식 원클릭)
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# 3) 셸 리로드
source ~/.bashrc

# 4) 진단 — 여기서 전부 통과해야 다음 단계로
hermes doctor

# 5) 대화형 초기 셋업 마법사
hermes setup
```

> 호스팅어는 **Hermes Agent 전용 템플릿**을 제공합니다.
> VPS 생성 시 OS 대신 이 템플릿을 고르면 위 2번 단계가 생략됩니다.

### 2-B. macOS / WSL2 — 로컬 테스트용

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.zshrc     # bash 쓰시면 ~/.bashrc
hermes doctor
hermes setup
```

### 2-C. Windows 네이티브 — PowerShell

```powershell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

설치 후 **PowerShell 창을 완전히 닫고 새로 여세요.** (PATH 갱신)

```powershell
hermes doctor
hermes setup
```

> **Windows는 WSL2를 권합니다.** 네이티브 설치는 실행 정책, Defender/SmartScreen,
> 긴 경로 제한 등 걸리는 데가 많습니다. 24시간 운영이 목적이면 어차피 VPS가 정답입니다.

### 🔒 설치 전 보안 점검 — 스크립트 먼저 읽기

`curl ... | bash` 는 **원격 스크립트를 그대로 실행**하는 방식입니다. 편하지만 위험합니다.
불안하시면 다운로드해서 눈으로 확인한 뒤 실행하세요.

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o hermes-install.sh
less hermes-install.sh      # 내용 확인 (q 로 종료)
bash hermes-install.sh      # 확인 후 실행
```

설치 스크립트가 자동으로 넣는 것들: **Python 3.11, Node.js, ripgrep, ffmpeg, Git**

---

## 3. 모델 연결 (API 키 셋팅)

### 대화형 (권장 — 오타 위험 없음)

```bash
hermes model
```

프로바이더 목록에서 선택 → API 키 붙여넣기 → 모델 선택. 설정 파일이 자동으로 갱신됩니다.

### 수동 설정

설정 파일 위치를 먼저 확인하세요.

```bash
hermes config path        # config.yaml 경로
hermes config env-path    # .env 경로 (비밀키는 여기)
```

| OS | 설정 폴더 |
|---|---|
| Linux / macOS / WSL2 | `~/.hermes` |
| Windows 네이티브 | `%LOCALAPPDATA%\hermes` |

**`~/.hermes/.env`** — 비밀키는 반드시 여기에만

```env
# OpenRouter 경로 (권장)
OPENROUTER_API_KEY=sk-or-v1-여기에_본인_키

# 또는 Anthropic 직접 경로
ANTHROPIC_API_KEY=sk-ant-여기에_본인_키
```

**`~/.hermes/config.yaml`** — 모델 지정

```yaml
model:
  default: "anthropic/claude-opus-4.6"
```

> 헤르메스는 **설정(config.yaml)과 비밀키(.env)를 분리**해서 관리합니다.
> API 키를 `config.yaml`에 적지 마세요. 실수로 공유되기 쉽습니다.

### 연결 확인

```bash
hermes
# 대화창이 뜨면 아무거나 물어보세요. 답이 오면 연결 성공.
```

**401 / 403 에러가 나면** → API 키가 없거나, 오래됐거나, 크레딧이 0원입니다.
`hermes model` 을 다시 돌려서 키를 재입력하면 설정이 한 번에 다시 써집니다.

---

## 4. 슬랙 연동 (회사 운영용)

영상의 핵심인 "회사 운영 레이어" 부분입니다. 슬랙에 붙여야 실무에서 씁니다.

### 4-1. 슬랙 앱 만들기

1. https://api.slack.com/apps → **Create New App** → From scratch
2. **Socket Mode** 켜기 → 생성된 **App-Level Token** 복사 → 이게 `SLACK_APP_TOKEN` (`xapp-` 시작)
3. **OAuth & Permissions** → Bot Token Scopes 추가
   (`app_mentions:read`, `chat:write`, `channels:history`, `im:history`, `im:write`)
4. **Install to Workspace** → **Bot User OAuth Token** 복사 → 이게 `SLACK_BOT_TOKEN` (`xoxb-` 시작)
5. **Event Subscriptions** 켜기 → `app_mention`, `message.im` 구독

### 4-2. 헤르메스에 등록

`~/.hermes/.env` 에 추가:

```env
SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
SLACK_ALLOWED_USERS=U01ABCDEFG        # 본인 슬랙 유저 ID (쉼표로 여러 명)
```

> **`SLACK_ALLOWED_USERS` 는 반드시 채우세요.** 비워두면 워크스페이스 아무나
> 에이전트를 조종할 수 있습니다. 회사 슬랙이면 사고로 이어집니다.

### 4-3. 게이트웨이 실행 (24시간 상주)

```bash
hermes gateway install
hermes gateway start
```

VPS(리눅스)에서 재부팅 후에도 자동 실행되게 하려면:

```bash
sudo hermes gateway install --system
```

### 텔레그램이 더 편한 경우

개인용이면 텔레그램이 훨씬 가볍습니다.

1. 텔레그램에서 `@BotFather` → `/newbot` → 토큰 발급

```env
TELEGRAM_BOT_TOKEN=1234567890:AAxx...
TELEGRAM_ALLOWED_USERS=123456789      # 본인 텔레그램 숫자 ID
TELEGRAM_HOME_CHANNEL=-1001234567890  # (선택) 기본 채널
```

---

## 5. MD 실무 자동화 시나리오

영상에서 다루는 활용안을 유통 벤더 MD 업무에 맞춰 옮기면:

| 시나리오 | 내용 | 트리거 |
|---|---|---|
| **아침 브리핑** | 전일 채널별 매출·주문건수 요약을 슬랙으로 | 매일 08:30 |
| **재고 소진 알림** | 안전재고 이하 SKU를 자동 감지해 알림 | 매일 / 실시간 |
| **경쟁사 가격 모니터링** | 주요 SKU 최저가 변동 추적 | 매일 09:00 |
| **회의록 액션아이템 추출** | 회의록 붙여넣으면 담당자·기한별로 정리 | 수동 호출 |
| **상세페이지 초안** | 스펙 시트 → 소비자 언어 카피로 변환 | 수동 호출 |
| **플랫폼 MD 메일 초안** | 협의 포인트 입력 → 격식 있는 제안 메일 | 수동 호출 |

> 처음부터 전부 붙이지 마세요. **아침 브리핑 하나만** 2주 돌려보고,
> 안정적으로 도는 걸 확인한 다음 하나씩 늘리는 게 실패 확률이 낮습니다.

---

## 6. 보안 수칙 (회사 데이터를 다룬다면 필수)

1. **`.env` 파일은 절대 깃/드라이브/카톡으로 공유하지 않기.** API 키 = 결제 수단입니다.
2. **`*_ALLOWED_USERS` 를 반드시 채우기.** 안 채우면 아무나 에이전트를 조종합니다.
3. **VPS는 SSH 키 인증으로.** 루트 비밀번호 로그인은 꺼두세요.
4. **에이전트에 회사 기간계(ERP/WMS) 쓰기 권한을 바로 주지 말 것.** 읽기 전용으로 시작하세요.
5. **거래처 단가·계약 조건 같은 대외비는 넣기 전에 한 번 더 판단.** 외부 API로 전송됩니다.
6. **지출 한도 설정.** 1번만큼 중요합니다.

---

## 7. 문제 생겼을 때

```bash
hermes doctor     # 만능 진단 — 뭐가 문제인지 대부분 여기서 나옵니다
hermes update     # 최신 버전으로 갱신
```

| 증상 | 원인 | 해결 |
|---|---|---|
| `hermes: command not found` | PATH 미갱신 | `source ~/.bashrc` / 터미널 새로 열기 |
| `401` / `403` | API 키 없음·만료·크레딧 0 | `hermes model` 재실행 |
| 설치 중 다운로드 실패 | 사내 프록시/방화벽 | 아래 사내망 항목 참고 |
| PowerShell 스크립트 차단 | 실행 정책 | `Set-ExecutionPolicy -Scope Process RemoteSigned` |
| 슬랙 봇 무응답 | 게이트웨이 미실행 | `hermes gateway start` |

### 🏢 사내망에서 설치가 막히는 경우

유통사 사내망은 npm/PyPI/GitHub 아웃바운드를 막아둔 경우가 많습니다.
설치 전에 `preflight-check.sh` 를 먼저 돌려서 확인하세요.

막혀 있다면 선택지는 셋입니다:
1. **VPS에 설치** (사내망과 무관해짐) ← 가장 깔끔
2. 정보보안팀에 프록시 예외 요청
3. 개인 네트워크(테더링)에서 설치 후 사내망에서 운영

---

## 참고 자료

- [NousResearch/hermes-agent (GitHub)](https://github.com/NousResearch/hermes-agent)
- [영상: 헤르메스 에이전트 설치부터 회사 운영 자동화까지](https://youtu.be/j5CIK1pcf3A)
- [Anthropic, 서드파티 도구의 구독 OAuth 토큰 금지](https://openclaw.report/ecosystem/anthropic-bans-oauth-tokens-third-party-tools)
- [Hermes Agent에서 Claude 구독을 지원하지 않는 이유](https://openclawlaunch.com/guides/hermes-claude-subscription)
