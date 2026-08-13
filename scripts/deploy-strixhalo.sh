#!/bin/sh
# Deploy the Mojo Adrenalin backend to strixhalo.
# Bundle = binary + 3 Mojo runtime .so files (LD_LIBRARY_PATH=. at runtime).
# Build once locally, scp, restart via start.sh. Falls back to the Python
# server if the box can't run the binary (check: ssh strixhalo 'ldd ~/AMD-gui/app/adrenalin_server | grep "not found"').
set -e
cd "$(dirname "$0")/.."

echo "== build"
mojo build app/adrenalin.mojo -o app/adrenalin_server

echo "== bundle runtime"
M=/home/bcloud/.local/share/uv/tools/mojo/lib/python3.13/site-packages/modular/lib
mkdir -p app/runtime
cp "$M/libKGENCompilerRTShared.so" "$M/libMSupportGlobals.so" \
   "$M/libAsyncRTRuntimeGlobals.so" app/runtime/

echo "== push to strixhalo"
scp app/adrenalin_server app/runtime/*.so strixhalo:~/AMD-gui/app/runtime/ 2>/dev/null || {
    ssh strixhalo 'mkdir -p ~/AMD-gui/app/runtime'
    scp app/adrenalin_server app/runtime/*.so strixhalo:~/AMD-gui/app/runtime/
}
# stop first so the running binary isn't text-file-busy, then swap
ssh strixhalo 'pkill -f "adrenalin_serve[r]" 2>/dev/null; sleep 0.5; mv ~/AMD-gui/app/runtime/adrenalin_server ~/AMD-gui/app/adrenalin_server && chmod +x ~/AMD-gui/app/adrenalin_server'
ssh strixhalo 'cd ~/AMD-gui/app && LD_LIBRARY_PATH=runtime ./adrenalin_server --selftest | tail -1'
ssh strixhalo 'cd ~/AMD-gui/app && ./start.sh && sleep 1 && curl -s localhost:8080/api/metrics | head -c 120 && echo'
echo "== done: http://192.168.50.69:8080"
