#!/bin/bash
# =====================================================================
#  XRD Analyzer - open on http://localhost  (Linux / generic)
#
#  Run:  bash XRD-localhost.sh    (or make executable: chmod +x, then ./)
#
#  Why: opening the app as file:// lets the browser evict the IndexedDB
#  cache (your DB / projects). http://localhost is a proper origin, so
#  the data is kept far more reliably.  Requires Python 3.
# =====================================================================
PORT=8753
FILE=xrd_analyzer_v18.html

cd "$(dirname "$0")" || exit 1

if curl -s -o /dev/null "http://127.0.0.1:$PORT/$FILE"; then
  echo "Server already running on http://localhost:$PORT"
else
  echo "Starting local server on http://localhost:$PORT ..."
  nohup python3 -m http.server "$PORT" >"/tmp/xrd_http_$PORT.log" 2>&1 &
  disown
  sleep 1
fi

URL="http://localhost:$PORT/$FILE"
echo "Opening $URL"
# xdg-open on most Linux; fall back to a printed URL
xdg-open "$URL" 2>/dev/null || sensible-browser "$URL" 2>/dev/null || echo "Open this URL in your browser: $URL"

echo "You can close this terminal; the server keeps running."
