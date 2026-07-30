#!/bin/bash
# =====================================================================
#  XRD Analyzer - open on http://localhost  (Linux / generic)
#
#  Why: opening the app as file:// lets Chrome evict the IndexedDB cache
#  (your DB / projects) under disk pressure. http://localhost is a proper
#  origin, so the browser keeps the data far more reliably.
#
#  Keep this file inside the repo's launchers_mac folder, so that "cd .."
#  lands on the repo root where the HTML lives.
# =====================================================================
PORT=8753
FILE=xrd_analyzer_v23.html

cd "$(dirname "$0")/.." || exit 1   # serve the repo root, not launchers/

die(){ echo ""; echo "[ERROR] $1"; echo ""; read -r -p "Press Return to close." _; exit 1; }

# ---- Is the file actually here? -------------------------------------
if [ ! -f "$FILE" ]; then
  echo "[ERROR] Cannot find \"$FILE\" in:"
  echo "        $(pwd)"
  echo ""
  echo "Available builds:"
  ls -1 xrd_analyzer_v*.html 2>/dev/null | sed 's/^/  /' || echo "  (none)"
  die "Update the FILE= line at the top of this launcher, or restore the missing build."
fi

# ---- Python 3 present? ----------------------------------------------
PY=""
command -v python3 >/dev/null 2>&1 && PY=python3
[ -z "$PY" ] && command -v python >/dev/null 2>&1 && python -c 'import sys;exit(0 if sys.version_info[0]==3 else 1)' 2>/dev/null && PY=python
[ -z "$PY" ] && die "Python 3 was not found. Install it (https://www.python.org/downloads/) and run this again."

URL="http://localhost:$PORT/$FILE"

# ---- Is OUR file already served correctly on this port? -------------
#  Use curl -f so an HTTP 404 counts as failure. A plain "curl -s" exits 0
#  even on 404 (it connected fine), which is how a stale server rooted in
#  another folder used to be mistaken for a working one.
if curl -sf -o /dev/null "http://127.0.0.1:$PORT/$FILE"; then
  echo "Server already running correctly on http://localhost:$PORT"
else
  # ---- Free the port if a WRONG server is holding it ----------------
  BUSY="$(lsof -ti tcp:"$PORT" 2>/dev/null)"
  if [ -n "$BUSY" ]; then
    echo "Port $PORT is busy with a server that does not serve $FILE (PID $BUSY) — stopping it..."
    kill $BUSY 2>/dev/null
    sleep 1
    STILL="$(lsof -ti tcp:"$PORT" 2>/dev/null)"
    [ -n "$STILL" ] && kill -9 $STILL 2>/dev/null && sleep 1
  fi

  echo "Starting local server on http://localhost:$PORT ..."
  nohup "$PY" -m http.server "$PORT" >"/tmp/xrd_http_$PORT.log" 2>&1 &
  disown 2>/dev/null

  # ---- Wait until OUR file is actually reachable (up to ~15 s) ------
  READY=""
  for _ in $(seq 1 30); do
    if curl -sf -o /dev/null "http://127.0.0.1:$PORT/$FILE"; then READY=1; break; fi
    sleep 0.5
  done
  if [ -z "$READY" ]; then
    echo "Server log (/tmp/xrd_http_$PORT.log):"
    tail -n 5 "/tmp/xrd_http_$PORT.log" 2>/dev/null | sed 's/^/  /'
    die "The server did not come up on port $PORT. The port may be in use by another app, or Python was blocked. Change PORT at the top of this file and try again."
  fi
fi

echo "Opening $URL"
xdg-open "$URL" 2>/dev/null || sensible-browser "$URL" 2>/dev/null || echo "Open this URL in your browser: $URL"

echo ""
echo "You can close this terminal; the server keeps running."
