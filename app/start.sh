#!/bin/sh
# Start/restart the Adrenalin replica UI. Port override: ADRENALIN_PORT=9000 ./start.sh
# Prefers the Mojo 1.0 binary (adrenalin_server); falls back to the Python
# server. Build the binary with: mojo build adrenalin.mojo -o adrenalin_server
cd "$(dirname "$0")"
[ -f /tmp/adrenalin.pid ] && kill "$(cat /tmp/adrenalin.pid)" 2>/dev/null
sleep 0.5
if [ -x ./adrenalin_server ]; then
    setsid ./adrenalin_server > /tmp/adrenalin-server.log 2>&1 < /dev/null &
else
    setsid python3 -u adrenalin_server.py > /tmp/adrenalin-server.log 2>&1 < /dev/null &
fi
sleep 1
echo "Adrenalin replica: http://localhost:${ADRENALIN_PORT:-8080} (log: /tmp/adrenalin-server.log, pid: $(cat /tmp/adrenalin.pid 2>/dev/null))"
