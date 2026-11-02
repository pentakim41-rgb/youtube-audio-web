#!/data/data/com.termux/files/usr/bin/bash
# 휴대폰(Termux)에서 웹 버전 실행/관리.  install.sh 가 'yta' 명령으로 연결해 둔다.
#
#   yta           서버를 켜고(이미 켜져 있으면 그대로) 브라우저로 화면 열기
#   yta add URL   목록에 링크 추가 후 화면 열기 (유튜브 앱 '공유 → Termux' 가 이것을 부른다)
#   yta stop      서버 끄기
#   yta restart   서버 다시 켜기
#   yta update    프로그램 + yt-dlp 최신으로 업데이트 (유튜브 쪽이 바뀌어 안 받아질 때)
#   yta log       서버 로그 보기
#
# 자동 업데이트: 'yta' / 'yta add' 로 켤 때 하루에 한 번 프로그램과 yt-dlp 를 최신으로 맞춘다.
#   인터넷이 안 되면 건너뛰고 다음에 켤 때 다시 확인한다.
#   서버가 켜져 있고 목록에 곡이 남아 있으면, 다시 켜면 목록이 사라지므로 다음으로 미룬다.

APP_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
PORT=8765
URL="http://127.0.0.1:$PORT"
LOG="$HOME/.yta_server.log"
STAMP="$HOME/.yta_last_update"  # 마지막으로 업데이트를 확인한 시각 (파일 수정 시각)
UPDATE_EVERY_SEC=86400          # 하루
UPDATED=0                       # 이번에 프로그램이나 yt-dlp 가 바뀌었으면 1

running() {
    curl -s -m 2 "$URL/api/me" >/dev/null 2>&1
}

start_server() {
    running && return 0
    termux-wake-lock 2>/dev/null  # 화면을 꺼도 다운로드가 멈추지 않도록
    (cd "$APP_DIR" && nohup python -m web.server --port "$PORT" --no-browser >"$LOG" 2>&1 &)
    for _ in $(seq 1 40); do
        running && return 0
        sleep 0.5
    done
    echo "서버를 시작하지 못했습니다. 로그:"
    tail -n 20 "$LOG"
    return 1
}

stop_server() {
    pkill -f "web.server --port $PORT" 2>/dev/null
    termux-wake-unlock 2>/dev/null
}

open_ui() {
    termux-open-url "$URL"
}

# ---- 업데이트 ----------------------------------------------------------------------
pip_install() {
    pip install -q -U "$@" 2>/dev/null || pip install -q -U --break-system-packages "$@"
}

# 프로그램 새 코드 받기. 인터넷이 안 되면 1 을 돌려준다.
update_program() {
    local before
    before=$(git -C "$APP_DIR" rev-parse HEAD 2>/dev/null)
    timeout 60 git -C "$APP_DIR" fetch -q origin 2>/dev/null || return 1
    if ! git -C "$APP_DIR" merge -q --ff-only "@{u}" >/dev/null 2>&1; then
        echo "[경고] 프로그램 업데이트 실패 (git) - 프로그램 폴더의 파일을 직접 고쳤다면 되돌려 주세요."
        return 0
    fi
    if [ "$(git -C "$APP_DIR" rev-parse HEAD)" != "$before" ]; then
        echo "  프로그램을 새 버전으로 바꿨습니다."
        UPDATED=1
    fi
    return 0
}

# yt-dlp 가 PyPI 최신보다 오래됐으면 0
ytdlp_outdated() {
    (cd "$APP_DIR" && python -c 'import sys
from utils import updater as u
sys.exit(0 if u.is_outdated(u.installed_version(), u.latest_version()) else 1)') 2>/dev/null
}

update_ytdlp() {
    echo "  yt-dlp 업데이트 중... (1분 정도 걸릴 수 있습니다)"
    # [default] 의 일부 패키지는 휴대폰에서 빌드가 실패할 수 있어, 실패하면 꼭 필요한 것만
    if pip_install "yt-dlp[default]" || pip_install yt-dlp yt-dlp-ejs; then
        UPDATED=1
    else
        echo "[경고] yt-dlp 업데이트 실패"
    fi
}

# 켜져 있는 서버의 목록이 비어 있으면 0 (다시 켜도 잃을 것이 없다)
list_empty() {
    curl -s -m 3 "$URL/api/state" | python -c 'import json, sys
s = json.load(sys.stdin)
sys.exit(0 if not s["counts"]["total"] and not s["pending"] else 1)' 2>/dev/null
}

auto_update() {
    local last
    last=$(stat -c %Y "$STAMP" 2>/dev/null || echo 0)
    [ $(( $(date +%s) - last )) -lt "$UPDATE_EVERY_SEC" ] && return 0
    if running && ! list_empty; then
        return 0  # 받는 중이거나 목록에 곡이 있으면 다음에
    fi
    echo "업데이트 확인 중..."
    if ! update_program; then
        echo "  인터넷 연결이 없어 다음에 확인합니다."
        return 0
    fi
    touch "$STAMP"
    ytdlp_outdated && update_ytdlp
    if [ "$UPDATED" = 1 ] && running; then
        stop_server  # 새 버전으로 다시 켜지도록
        sleep 1
    fi
}

case "$1" in
    stop)
        stop_server
        echo "서버를 껐습니다."
        ;;
    restart)
        stop_server
        sleep 1
        start_server && open_ui
        ;;
    update)
        echo "업데이트 중..."
        update_program || echo "[경고] 프로그램 업데이트 실패 (인터넷 연결을 확인하세요)"
        update_ytdlp
        touch "$STAMP"
        stop_server
        sleep 1
        start_server && open_ui
        ;;
    add)
        auto_update
        start_server || exit 1
        body=$(python -c 'import json, sys; print(json.dumps({"jobs": [{"url": sys.argv[1], "playlist": False}]}))' "$2")
        curl -s -X POST -H "Content-Type: application/json" -H "X-Requested-With: yta" -d "$body" "$URL/api/add" >/dev/null
        open_ui
        ;;
    log)
        tail -n 50 "$LOG"
        ;;
    *)
        auto_update
        start_server && open_ui
        ;;
esac
