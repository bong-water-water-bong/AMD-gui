#!/bin/sh
# Rootless tuning writes for amd-gui.
# Installs a systemd-tmpfiles rule that chmods the amdgpu tuning attrs so
# members of the `video` group can write them (like corectrl does for hwmon).
# Run once as root:  sudo scripts/install-permissions.sh
set -e

RULE=/etc/tmpfiles.d/90-amd-gui.conf

cat > "$RULE" <<'EOF'
# AMD-gui: let the video group tune GPU clocks / perf levels
m /sys/class/drm/card*/device/pp_od_clk_voltage 0666 root video
m /sys/class/drm/card*/device/power_dpm_force_performance_level 0666 root video
EOF

systemd-tmpfiles --create "$RULE"

if [ -n "$SUDO_USER" ]; then
    usermod -aG video "$SUDO_USER" || true
fi

echo "Installed $RULE. Add yourself to the video group and re-login if needed:"
echo "  sudo usermod -aG video \$USER"
