# 헤르메스 에이전트(Hermes Agent) 설치 · 셋팅 가이드

> 대상: 개발자가 아닌 실무자 (온라인 MD / 유통 벤더 기준)
> 참고 영상: [헤르메스 에이전트 처음 써보는 분도 이 영상 하나로 끝납니다](https://youtu.be/j5CIK1pcf3A) — 빌더 조쉬, 2026-05-29
> 원본 저장소: [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) (MIT)

---

# 🚨 0. 시작 전 — 이거 안 읽고 시작하면 사고 납니다

## (1) 클로드 구독 연결 메뉴는 **보입니다. 그런데 누르면 안 됩니다.**

가장 중요한 정정입니다. "연결이 안 된다"가 아니라 **"연결은 되는데 하면 안 된다"** 입니다.

`hermes model` 을 실행하면 메뉴에 **Anthropic OAuth(클로드 계정 로그인)** 항목이 나옵니다.
심지어 PC에 Claude Code가 깔려 있으면 **기존 로그인 정보를 자동으로 찾아냅니다.**
눌러보면 작동하는 것처럼 보입니다. **그래서 위험합니다.**

앤트로픽 [Claude Code 법무·컴플라이언스 문서](https://code.claude.com/docs/en/legal-and-compliance)의 현행 문구:

> OAuth 인증은 Claude Free, Pro, Max, Team, Enterprise 구독 구매자 전용이며,
> **Claude Code 및 기타 네이티브 앤트로픽 애플리케이션의 통상적 사용**을 지원하도록 설계되었습니다.
>
> 앤트로픽은 서드파티 개발자가 자사 애플리케이션에 Claude.ai 로그인을 제공하거나,
> **사용자를 대신해 Free/Pro/Max 플랜 자격증명으로 요청을 라우팅하는 것을 허용하지 않습니다.**
> 개발자는 Claude.ai 자격증명이나 세션 토큰을 **수집·저장·중개해서는 안 됩니다.**
>
> 앤트로픽은 이 제한을 집행할 권리를 보유하며, **사전 통보 없이 조치할 수 있습니다.**

**헤르메스는 정확히 이 금지 행위를 합니다.** 소스 코드 확인 결과:
`agent/anthropic_credentials.py` 가 **Claude Code의 OAuth 클라이언트 ID를 하드코딩**하고,
User-Agent를 **`axios/1.7.9` 로 위장**하며, `~/.claude/.credentials.json` 을 읽습니다.
헤르메스 자체 문서도 이 경로가 *"Claude Code로서 당신의 앤트로픽 계정에 라우팅된다"* 고 설명합니다.

### ⚠️⚠️ 가장 위험한 함정 — 이름만 보고 안전하다고 착각하기

```
--provider claude        ← anthropic 의 별칭입니다
--provider claude-code   ← 이것도 anthropic 의 별칭입니다
```

"claude-code라고 써 있으니 공식 CLI를 부르는 안전한 경로겠지" 라고 생각하면 **정반대**입니다.
이 별칭들은 위에 설명한 **금지된 OAuth 경로를 그대로 탑니다.**

### 헤르메스 자체 문서가 밝히는 추가 제약

- **Claude Pro 구독자는 이 경로를 아예 쓸 수 없습니다.**
- Claude Max는 **별도 구매한 추가 사용량 크레딧으로만** 작동합니다.
  기본 Max 사용량은 **1원도 안 쓰이고**, 전부 초과분(overage)으로 청구됩니다.

### 🔴 사장님 용도(회사 슬랙 연동)에서 특히 위험한 지점

**슬랙에 붙여서 동료들이 에이전트를 부르게 하는 순간**, 개인 플랜으로
**타인의 클로드 사용을 중개**하는 것이 됩니다. 이건 약관에 명시적으로 금지돼 있고,
**계정 정지로 이어지는 가장 흔한 경로**입니다.

실제로 2026년 초 OpenCode·Cline·Roo Code·Kilo·OpenClaw 사용자들이 이 문제로 계정 정지를 당했습니다.

### 시간순 정리 (블로그마다 날짜가 다른 이유)

| 시점 | 사건 |
|---|---|
| 2026-01-09 | 서드파티 OAuth 요청이 에러를 뱉기 시작 |
| 2026-02-19 | 앤트로픽 법무 문서에 금지 문구 명시 |
| **2026-04-04 12pm PT** | 구독이 서드파티 하네스 사용을 **커버하지 않게 됨** (집행 시점) |
| 2026-05-13 | "Agent SDK 크레딧"으로 부분 부활 발표 |
| 2026-06-15 | 그 변경이 **보류(paused)** — 현재까지 미정 |

→ **결론: 상황이 아직 유동적입니다. 비개발자라면 발을 담그지 않는 게 맞습니다.**

---

## (2) 영상 설명의 "Codex OAuth 패치" 링크 — OAuth와 무관합니다

[issues/32883](https://github.com/NousResearch/hermes-agent/issues/32883) 을 직접 열어 확인했습니다.
**OpenAI Codex 연동 크래시(`TypeError: 'NoneType' object is not iterable`) 버그 픽스**입니다.
수정 파일: `agent/codex_responses_adapter.py`, `agent/codex_runtime.py`, `agent/conversation_loop.py`.
**OAuth·약관 우회 언급은 본문에 없습니다.**

## (3) 영상은 VPS 설치 방식이고, 호스팅 링크는 제휴 링크입니다

`JOSH10` 코드 = affiliate. 제품이 나쁘다는 게 아니라, 추천에 수익이 걸려 있다는 뜻입니다.
다만 **VPS 선택 자체는 타당합니다.** 헤르메스 README도 *"노트북에 묶여 있지 않다 —
클라우드 VM에서 돌리고 텔레그램으로 대화하라"* 고 명시하고, 터미널 백엔드를
로컬/Docker/SSH/Singularity/Modal/Daytona/Vercel Sandbox 7종 지원합니다.

---

# 💰 1. 비용 — 여기서 대부분 사고가 납니다

## 실제 예상 비용 (하루 3시간 사용 가정)

| 모델 | 입력/출력 (per MTok) | 월 예상 |
|---|---|---|
| Claude Haiku 4.5 | $1 / $5 | 가장 저렴 |
| Claude Sonnet 5 | $2 / $10 | **$76 ~ 190** |
| Claude Opus 5 | $5 / $25 | **$190 ~ 270** |
| Claude Fable 5 | $10 / $50 | **$380 ~ 540** |

**Claude Pro($20)나 Max($200) 구독보다 훨씬 비쌉니다.** 구독은 대안이 아닙니다.

## 🔥 반드시 먼저 조치할 3가지

### ① 기본 모델을 직접 지정하세요 — 안 하면 최고가 모델이 걸립니다

**모델을 지정하지 않으면 헤르메스는 `claude-fable-5`($10/$50)를 기본값으로 씁니다.**
Sonnet 5의 **5배 단가**입니다. 반드시 명시적으로 골라주세요.

### ② `HERMES_MAX_ITERATIONS` 를 낮추세요 — 기본값이 500입니다

한 번의 질문에 도구 호출을 **500회까지** 반복합니다.
지시 하나 잘못 이해하면 **한 턴에 Opus 5로 $37, Fable 5로 $75** 가 날아갑니다.

```env
HERMES_MAX_ITERATIONS=30
```

### ③ 지출 한도 + 선불 크레딧 — 앤트로픽 기본값은 0원이 아닙니다

**신규 Start 등급의 기본 상한은 월 $500입니다.** 안 걸어두면 $500까지 열려 있습니다.

- [platform.claude.com](https://platform.claude.com) → Settings → Billing → Spend limits → 예: **$50**
- **선불 크레딧 $20만 충전하고 auto-reload는 OFF** ← 이게 진짜 안전장치입니다.
  auto-reload를 켜면 상한이 사라집니다.

> **헤르메스에는 앤트로픽 경로용 자체 예산 상한 기능이 없습니다.**
> (`member_spend_cap_usd` 는 Nous Portal 전용) 브레이크는 콘솔 설정과 선불 크레딧뿐입니다.

## 알아두면 돈 아끼는 것들

- **프롬프트 캐시 TTL이 API 키는 5분, 구독은 1시간.** 띄엄띄엄 물어보면 캐시를 계속 놓쳐서
  같은 작업이 **약 3.2배** 비싸집니다 ($270 → $873). **질문은 몰아서 하세요.**
- **내가 안 시킨 지출이 있습니다.** 스킬 큐레이터가 `max_iterations=9999` 로 자율 실행되고
  (한 번에 50~100 API 콜), 크론 스케줄러는 자는 동안에도 턴을 돕니다.
- **헤르메스가 화면에 찍는 "~$0.12" 같은 비용 표시를 믿지 마세요.**
  내장 가격표(`agent/usage_pricing.py`)에 `claude-opus-5` 항목이 아예 없고,
  Sonnet 5가 9/1에 $3/$15로 올랐다고 가정하고 있습니다 (실제로는 안 올랐고 $2/$10입니다).
- **Opus 5 / Fable 5는 신형 토크나이저**라 같은 한글 텍스트에 토큰이 **약 30% 더** 나옵니다.

## 프로바이더 선택

| 경로 | 인증 | 실제 비용 감각 | 약관 | 추천 |
|---|---|---|---|---|
| **Anthropic API 직접** | `ANTHROPIC_API_KEY` | 종량제, 위 표 그대로 | ✅ | ⭐ **모호함 없음 — 권장** |
| **OpenRouter** | `OPENROUTER_API_KEY` | **토큰 단가는 동일**, 크레딧 구매 시 ~5.5% 수수료 | ✅ | 여러 모델 갈아탈 때 |
| **Nous Portal** | 포털 구독 $20/mo | 앤트로픽 $20 충전과 대략 본전 | ✅ | 웹검색·이미지·TTS 툴 묶음이 필요할 때 |
| **로컬 Ollama** | 불필요 | 무료 (사양 필요) | ✅ | 사양 좋을 때 |
| ~~Anthropic OAuth~~ | ~~클로드 로그인~~ | ~~Pro 불가 / Max는 초과분만~~ | ❌ **금지** | **절대 금지** |

> **정정**: 앞서 "OpenRouter가 더 저렴"하다고 안내했는데 **틀렸습니다.**
> OpenRouter는 클로드 토큰 단가에 마크업을 붙이지 않습니다 = 앤트로픽 직접과 **같은 단가**입니다.
> 크레딧 구매 시 ~5.5%(최소 $0.80)가 붙으므로 오히려 아주 약간 비쌉니다.
> 장점은 **가격이 아니라** 잔액 하나로 300여 개 모델을 쓰고 저렴한 오픈모델로 폴백할 수 있다는 점입니다.
>
> 비개발자에게는 **앤트로픽 API 키 직접**을 권합니다. 약관상 모호함이 전혀 없는 유일한 경로입니다.

---

# 2. 설치

## ⛔ 설치 전 하드 블로커 확인

| 조건 | 결과 |
|---|---|
| **인텔 맥 (M시리즈 아님)** | ❌ **공식 미지원.** 설치하지 마세요. |
| **32비트 윈도우** | ❌ 사실상 불가 (터미널 도구·브라우저 작동 안 함) |
| **Python 3.14** | ❌ 설치 실패 (`pydantic-core` 휠 없음) |
| **Node 23.x / 25.x** | ❌ 거부됨. 22.22+ / 24.11+ / 26+ 만 통과 |

> `pip install hermes-agent`, `brew install hermes-agent`, `uv tool install` 은
> **전부 공식 미지원**입니다. 설치 스크립트가 git 저장소를 클론하는 방식뿐입니다.

## 2-A. VPS (우분투) — 영상 방식 · 권장

```bash
ssh root@<VPS_IP>

# 리눅스에서 실제로 발목 잡는 건 파이썬이 아니라 xz-utils 입니다.
# Node를 .tar.xz 로 받아서 푸는데, 없으면 실패합니다.
sudo apt update && sudo apt install -y curl xz-utils git
# (선택) 데스크톱 앱까지 쓸 거면 C++ 컴파일러도 필요합니다
# sudo apt install -y build-essential

curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
hermes doctor
```

> **sudo로 설치하지 마세요.** 일반 사용자로 돌려야 `~/.local/bin` 에 정상 설치됩니다.
> sudo로 한 번 깔면 `/usr/local/bin/hermes` 가 남아서 진짜 설치를 가립니다.
> 이미 그랬다면: `sudo rm /usr/local/bin/hermes` 후 재설치.

**설치 후 바로 셋업 마법사가 뜨는 게 싫다면:**
```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
```

## 2-B. macOS (**애플 실리콘 전용**)

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.zshrc
hermes doctor
```

> **새 맥에서는 설치 중 `xcode-select --install` 팝업이 뜹니다.**
> 클릭하고 라이선스에 동의해야 진행됩니다. 모르면 **멈춘 줄 알고 강제 종료하게 됩니다.**

## 2-C. 윈도우 (네이티브 — 정식 지원됩니다)

```powershell
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
```

> **정정**: 앞서 "WSL2를 권한다"고 했는데, 확인 결과 **윈도우 10/11 네이티브가 Tier-1 정식 지원**입니다.
> **관리자 권한도 필요 없습니다.** 빠지는 기능은 웹 대시보드의 내장 터미널 창 하나뿐입니다.
> 설치 위치: `%LOCALAPPDATA%\hermes`

설치 후 **PowerShell 창을 완전히 닫고 새로 여세요.** 윈도우에는 `source` 명령이 없습니다.

```powershell
Get-Command hermes
hermes doctor
```

## 🔒 파이프 실행 전 — 저장소 원본과 대조하기

`curl | bash` 는 검토되지 않은 원격 스크립트를 셸에 그대로 붓는 방식입니다.
**설치 스크립트는 저장소에도 공개돼 있으니 대조해서 확인할 수 있습니다.**
(저장소 경로는 루트가 아니라 `scripts/` 아래입니다.)

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o ~/hermes-install.sh
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh -o ~/hermes-install-repo.sh
diff ~/hermes-install.sh ~/hermes-install-repo.sh && echo '동일함 — 진행해도 됩니다'
less ~/hermes-install.sh        # 눈으로 확인 (q 로 종료)
bash ~/hermes-install.sh
```

윈도우:
```powershell
irm https://hermes-agent.nousresearch.com/install.ps1 -OutFile $env:USERPROFILE\hermes-install.ps1
irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1 -OutFile $env:USERPROFILE\hermes-install-repo.ps1
if ((Get-FileHash $env:USERPROFILE\hermes-install.ps1).Hash -eq (Get-FileHash $env:USERPROFILE\hermes-install-repo.ps1).Hash) { '동일함' } else { '다름 — 실행하지 마세요' }
```

> **"2분 안에 끝납니다"는 마케팅 문구입니다.** Python·Node·PortableGit(57MB)을 받고
> 저장소를 클론하고 uv 설치를 돌립니다. 스크립트 자체 주석도 PortableGit 다운로드만
> 5분 넘게 걸릴 수 있다고 적어놨습니다.

---

# 3. 모델 연결

## ⚠️ `hermes model` 메뉴에서 고르면 안 되는 항목

```
  ...
  Anthropic OAuth  /  "Log in with your Claude account"   ← ❌ 고르지 마세요
  Anthropic (API key)                                     ← ✅ 이걸 고르세요
  ...
```

## 대화형 (권장)

```bash
hermes model
```

> **`/model` 을 채팅 안에서 치면 안 됩니다.** 이미 설정된 프로바이더끼리 전환만 됩니다.
> 새 프로바이더 추가나 API 키 입력은 **채팅을 나간 뒤(`/quit`) 셸에서 `hermes model`** 로 해야 합니다.
> 이게 가장 흔한 "왜 안 되지?" 원인입니다.

## 수동 설정

```bash
hermes config path        # config.yaml 경로
hermes config env-path    # .env 경로
```

| OS | 설정 폴더 |
|---|---|
| Linux / macOS / WSL | `~/.hermes/` |
| Windows | `%LOCALAPPDATA%\hermes\` |

```bash
# 비밀키 — .env 에만. config.yaml 에 넣지 마세요.
hermes config set ANTHROPIC_API_KEY sk-ant-api03-여기에_본인_키
chmod 600 ~/.hermes/.env

# 모델 — 반드시 명시적으로 지정 (안 하면 최고가 fable-5)
hermes config set model.provider anthropic
hermes config set model.default claude-sonnet-5
```

### ⚠️ 모델 ID 형식이 경로마다 다릅니다

| 경로 | 형식 | 예시 |
|---|---|---|
| **앤트로픽 직접** | 하이픈, 접두사 **없음** | `claude-sonnet-5`, `claude-opus-5` |
| **OpenRouter / Nous Portal** | `벤더/` 접두사 + 점 | `anthropic/claude-opus-4.7` |

- **섞어 쓰면 조용히 다른 경로로 넘어갑니다.** 에러가 안 나서 알아채기 어렵습니다.
- **날짜 접미사를 붙이지 마세요.** `claude-opus-5-20260401` 같은 건 404입니다.
- **점(.)이 들어간 모델 ID는 `hermes config set` 이 깨집니다.** (점을 중첩 키 구분자로 해석)
  → 하이픈 형식을 쓰거나 `hermes config edit` 으로 직접 편집하세요.

### 확인

```bash
hermes config show
hermes doctor              # ✅ 평소엔 이걸로
# hermes doctor --live     # ⚠️ 실제 과금되는 API 호출을 합니다. 필요할 때만.
```

### 자주 걸리는 함정

- **셸에 export한 `ANTHROPIC_API_KEY` 가 `.env` 보다 우선합니다.**
  엉뚱한 키를 쓰는 것 같으면 `env | grep ANTHROPIC` 과 `~/.bashrc` 를 먼저 확인하세요.
- **설정 우선순위**: CLI 인자 > config.yaml > .env > 기본값
- **실행 중인 채팅 세션은 설정을 다시 안 읽습니다.** 모델을 바꿨으면 **새 세션**을 여세요.

---

# 4. 슬랙 / 텔레그램 연동

> 🔴 **다시 강조**: 슬랙에 붙여 **동료들이 쓰게 하는 순간**, 개인 클로드 플랜으로
> 타인의 사용을 중개하는 게 됩니다 (OAuth 경로일 때). **API 키 경로를 쓰신다면 이 문제는 없습니다.**
> 어느 쪽이든 `*_ALLOWED_USERS` 는 반드시 채우세요.

## 슬랙

1. https://api.slack.com/apps → Create New App → From scratch
2. **Socket Mode** 켜기 → App-Level Token (`xapp-`) 복사
3. OAuth & Permissions → Bot Token Scopes:
   `app_mentions:read`, `chat:write`, `channels:history`, `im:history`, `im:write`
4. Install to Workspace → Bot User OAuth Token (`xoxb-`) 복사
5. Event Subscriptions → `app_mention`, `message.im`

```env
SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
SLACK_ALLOWED_USERS=U01ABCDEFG     # ⚠️ 비우면 워크스페이스 아무나 조종 가능
```

## 텔레그램 (개인용 · 더 가벼움)

```env
TELEGRAM_BOT_TOKEN=1234567890:AAxx...
TELEGRAM_ALLOWED_USERS=123456789   # ⚠️ 비우면 봇 아는 사람 아무나 조종 가능
TELEGRAM_HOME_CHANNEL=-1001234567890
```

## 게이트웨이 실행

```bash
hermes gateway install
hermes gateway start
sudo hermes gateway install --system    # 리눅스: 재부팅 후 자동 실행
```

---

# 5. MD 실무 자동화 시나리오

| 시나리오 | 트리거 |
|---|---|
| 아침 브리핑 (전일 채널별 매출·주문건수) | 매일 08:30 |
| 재고 소진 알림 (안전재고 이하 SKU) | 매일 |
| 경쟁사 가격 모니터링 | 매일 09:00 |
| 회의록 → 담당자·기한별 액션아이템 | 수동 |
| 스펙시트 → 소비자 언어 상세페이지 카피 | 수동 |
| 플랫폼 MD 협의 메일 초안 | 수동 |

> **아침 브리핑 하나만 2주 돌려보고** 비용과 안정성을 확인한 뒤 늘리세요.
> 크론이 자는 동안에도 돌면서 토큰을 씁니다.

---

# 6. 보안 수칙

1. **`.env` 를 깃/드라이브/카톡으로 공유 금지.** API 키 = 결제 수단.
2. **`*_ALLOWED_USERS` 반드시 설정.**
3. **VPS는 SSH 키 인증.** 루트 비밀번호 로그인 끄기.
4. **기간계(ERP/WMS)는 읽기 전용부터.** 쓰기 권한을 처음부터 주지 마세요.
5. **거래처 단가·계약 조건은 넣기 전에 한 번 더 판단.** 외부 API로 전송됩니다.
6. **지출 한도 설정.** 1번만큼 중요합니다.
7. **`--dangerously-skip-permissions` 를 쓰는 스킬 주의.** 헤르메스의 일부 스킬은
   권한 확인 창을 전부 건너뜁니다. 자율 실행 + 권한 무시 조합은 위험합니다.

---

# 7. 문제 해결

```bash
hermes doctor      # 만능 진단 (과금 없음)
hermes update      # 최신 버전
```

| 증상 | 진짜 원인 | 해결 |
|---|---|---|
| `hermes: command not found` | **거의 항상 PATH 미갱신.** 설치 실패 아님 | `source ~/.bashrc` / 새 터미널 |
| `unable to get local issuer certificate` | **사내망 TLS 가로채기.** 권한 문제 아님 | 정보보안팀에 사내 CA 등록 요청 |
| `ModuleNotFoundError: dotenv` | 저장소 소스를 직접 실행 중 | 설치된 `hermes` 명령을 쓰세요 |
| `401` | API 키 무효 | `hermes model` 재실행 |
| `(couldn't verify)` / `(HTTP nnn)` | **403일 수 있음** — 헤르메스가 403을 따로 해석 안 함 | 사내 프록시 차단 의심 |
| `RPC failed; HTTP 429` | GitHub 저장소 스로틀. 방화벽 아님 | 잠시 후 재시도 |
| PowerShell 차단 | 실행 정책 | `Set-ExecutionPolicy -Scope Process RemoteSigned` |
| uv.exe 격리됨 | Defender/Bitdefender 오탐 | 예외 등록 (회사 PC면 IT 필요) |

## 🏢 사내망 — 설치가 최소 9개 호스트를 씁니다

`github.com`, `nodejs.org`, `astral.sh`, `pypi.org`, `npmmirror.com`,
`git-scm.com`, `raw.githubusercontent.com`, `duckduckgo.com`, `hermes-agent.nousresearch.com`

**하나만 막혀도 설치가 엉뚱한 단계에서 깨집니다.** 그래서 `preflight-check.sh` 를 먼저 도세요.

> **호스트 설치에는 사내 프록시/CA를 설정하는 공식 지원 방법이 없습니다.**
> (`HTTPS_PROXY`/`NODE_EXTRA_CA_CERTS` 문서는 헤르메스 자체 Docker 샌드박스용입니다.)

### `hermes-agent.nousresearch.com` 만 막힌 경우 — 공식 대체 경로가 있습니다

배포 도메인만 차단되고 GitHub은 열려 있다면, 공식 문서가 안내하는 저장소 직접 경로를 쓰세요.

```powershell
# 윈도우
iex (irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1)
```

```bash
# 리눅스 / macOS
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
```

단, 설치 중에 `nodejs.org`, `astral.sh`, `pypi.org` 등도 받으므로 **그 호스트들이 열려 있어야** 끝까지 갑니다.
→ 여러 개가 막혀 있으면 **VPS 설치가 사실상 유일한 현실적 답**입니다.

---

## 참고 자료

- [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)
- [Anthropic — Claude Code 법무·컴플라이언스](https://code.claude.com/docs/en/legal-and-compliance)
- [Anthropic Console (platform.claude.com)](https://platform.claude.com)
- [영상: 헤르메스 에이전트 설치부터 회사 운영 자동화까지](https://youtu.be/j5CIK1pcf3A)
- [Anthropic, 서드파티 도구의 구독 OAuth 금지](https://openclaw.report/ecosystem/anthropic-bans-oauth-tokens-third-party-tools)

> 조사 방법: 영상 자막은 YouTube의 클라우드 IP 차단으로 수집하지 못해, 영상 메타데이터와
> 공식 저장소 원본(`README.md`, `scripts/install.sh`, `scripts/install.ps1`,
> `cli-config.yaml.example`, `.env.example`, `agent/anthropic_credentials.py`,
> `agent/usage_pricing.py`) 및 앤트로픽 공식 문서를 대조해 작성했습니다.
> 주요 주장은 3개 관점(사실 정확성 / 약관 리스크 / 실무 현실성)으로 교차 반박 검증했습니다.
