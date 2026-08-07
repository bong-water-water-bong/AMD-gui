#!/bin/sh
# Build the amd-gui .deb from the current tree.
# Needs: cmake, qt6-base-dev qt6-declarative-dev, qml6-module-*, dpkg-deb
set -e
cd "$(dirname "$0")/.."

VERSION=$(grep -oP 'project\(amd-gui VERSION \K[0-9.]+' CMakeLists.txt)

cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j"$(nproc)"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/DEBIAN"
DESTDIR="$STAGE" cmake --install build >/dev/null
cp packaging/DEBIAN/control packaging/DEBIAN/postinst packaging/DEBIAN/postrm "$STAGE/DEBIAN/"
echo "Installed-Size: $(du -s "$STAGE" | awk '{print $1}')" >> "$STAGE/DEBIAN/control"

DEB="amd-gui_${VERSION}_amd64.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$DEB" >/dev/null
echo "Built $DEB"
