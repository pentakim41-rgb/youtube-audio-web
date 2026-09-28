# 유튜브 → MP3/WAV 변환기 (웹 버전)

브라우저 화면으로 쓰는 버전입니다. PC 에서 서버를 켜고 PC 나 같은 와이파이의 휴대폰 브라우저로 접속하거나,
안드로이드 휴대폰(Termux) 안에서 직접 돌릴 수 있습니다. PC 창 버전은 옆의 `youtube_audio` 폴더에 있습니다.

> 본인이 올린 영상이나 재사용이 허용된 콘텐츠에만 사용하세요.

## PC 에서 실행 (Windows)

1. Python 3.10+ 설치
2. `run.bat` 더블클릭 — 처음에는 가상환경을 만들고 패키지를 자동 설치한 뒤 브라우저가 열립니다.
3. Deno 가 필요합니다: `winget install DenoLand.Deno` (또는 `bin/deno.exe`)

직접 실행: `pip install -r requirements.txt` → `python -m web.server`

| 옵션 | 하는 일 |
|---|---|
| `--local-only` | 이 PC 에서만 접속 허용 (기본은 같은 와이파이의 다른 기기도 PIN 으로 접속 가능) |
| `--no-browser` | 시작할 때 브라우저를 열지 않음 |
| `--port 8765` | 포트 변경 |

## 안드로이드

[android/README.md](android/README.md) 참고.

## 저장 위치

- 곡: 이 폴더의 `추출사운드` (설정에서 변경)
- 설정·기록·로그: `%APPDATA%\YouTubeAudioWeb` — PC 버전과 따로 저장됩니다.

## 테스트

`python -m pytest -q tests`
