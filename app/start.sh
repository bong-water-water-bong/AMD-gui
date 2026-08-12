#!/bin/sh
# Start/restart the Adrenalin replica UI. Port override: ADRENALIN_PORT=9000 ./start.sh
cd "$(dirname "$0")"
[ -f /tmp/adrenalin.pid ] && kill "$(cat /tmp/adrenalin.pid)" 2>/dev/null
sleep 0.5
setsid python3 -u adrenalin_server.py > /tmp/adrenalin-server.log 2>&1 < /dev/null &
sleep 1
echo "Adrenalin replica: http://localhost:${ADRENALIN_PORT:-8080} (log: /tmp/adrenalin-server.log, pid: $(cat /tmp/adrenalin.pid 2>/dev/null))"
