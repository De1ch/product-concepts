#!/usr/bin/env bash
# Free external watch of the page and the Apps Script web app (run by .github/workflows/ping.yml in this PUBLIC repo: Actions minutes are unlimited here).
# Env: PAGE_URL (default https://loopah.me/), APPS_URL (the /exec address, a secret), TG_BOT_TOKEN, TG_CHAT_ID, PREV (conclusion of the previous run: success|failure|empty),
#      TG_THREAD (optional topic id; empty = General), DRY=1 (print the message instead of sending).
# Exit 1 when something is down (so the run shows red and GitHub also e-mails the owner). The Telegram message is sent only when the state CHANGES (down / recovered).
set -u
PAGE_URL="${PAGE_URL:-https://loopah.me/}"; PREV="${PREV:-}"; bad=0; why=""
page=$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -L "$PAGE_URL" 2>/dev/null || true); [ -n "$page" ] || page=000
if [ "$page" != 200 ]; then bad=1; why="${why}Страница ${PAGE_URL} ответила ${page}\n"; fi
if [ -n "${APPS_URL:-}" ]; then
  body=$(curl -s --max-time 30 -L "${APPS_URL}?action=ping" 2>/dev/null || true)
  if ! printf '%s' "$body" | grep -q '"ok":true'; then bad=1; why="${why}Скрипт таблицы (Apps Script) не отвечает или отвечает не так\n"; fi
fi
send() {
  local text="$1"
  if [ "${DRY:-0}" = 1 ]; then printf '%b\n' "$text"; return 0; fi
  [ -n "${TG_BOT_TOKEN:-}" ] && [ -n "${TG_CHAT_ID:-}" ] || { echo "no Telegram settings: not sent"; return 0; }
  curl -s --max-time 20 -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" -d "chat_id=${TG_CHAT_ID}" -d "parse_mode=HTML" -d "disable_web_page_preview=true" \
    ${TG_THREAD:+-d "message_thread_id=${TG_THREAD}"} --data-urlencode "text=$(printf '%b' "$text")" >/dev/null || true
}
if [ "$bad" = 1 ]; then
  echo "DOWN: $(printf '%b' "$why")"
  [ "$PREV" = failure ] || send "<b>🛠 Инфраструктура</b>\n<b>🔴 Недоступно снаружи</b>\n\n${why}Проверка из GitHub Actions, раз в 10 минут.\n#инфраструктура #мониторинг"
  exit 1
fi
echo "UP: page $page"
[ "$PREV" != failure ] || send "<b>🛠 Инфраструктура</b>\n<b>🟢 Снова в порядке</b>\n\nСтраница и скрипт таблицы отвечают.\n#инфраструктура #мониторинг"
exit 0
