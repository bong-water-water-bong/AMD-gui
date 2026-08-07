# AMD-gui — Strix Halo sysfs backend surface (verified on this box)

Kernel 7.1.5, amdgpu (gfx1151, Radeon 8060S). All paths below verified
readable; write-capable ones noted. Units are the raw sysfs units
(m°C, µW, kHz-ish MHz strings).

## Metrics (read)

| Data | Path | Value seen |
|---|---|---|
| GPU busy % | `/sys/class/drm/card1/device/gpu_busy_percent` | 2 |
| VCN busy % | `/sys/class/drm/card1/device/vcn_busy_percent` | — |
| GPU temp | `/sys/class/hwmon/hwmon5/temp1_input` (m°C) | 40000 → 40°C |
| GPU power now | `/sys/class/hwmon/hwmon5/power1_input` (µW) | 27.1 W |
| GPU power avg | `/sys/class/hwmon/hwmon5/power1_average` (µW) | 27.1 W |
| CPU temp | `/sys/class/hwmon/hwmon2/k10temp/temp1_input` | — |
| Voltage rails | `hwmon5/in0_input`, `in1_input` | 0 (not populated on this APU) |

## Tuning (write) — the "control" surface

| Control | Path | Surface |
|---|---|---|
| Clock states | `pp_dpm_sclk/mclk/socclk/fclk/dcefclk/pcie` | `0: 600Mhz / 1: 845Mhz * / 2: 2900Mhz` |
| Perf level | `power_dpm_force_performance_level` | `auto` (auto/high/low/manual) |
| Overdrive | `pp_od_clk_voltage` | `OD_SCLK: 600–2900 MHz`, `OD_RANGE: 600–2900` (read; writes set min/max, `c` commits, `r` resets) |
| Power profile | `pp_power_profile_mode` | empty on this platform — unsupported |
| Fan | — | **not exposed** via amdgpu (mini-PC chassis fan; EC-controlled) |
| CPU cTDP | ryzenadj (not installed) | kernel + PMF handle policy |

ppfeaturemask = 0xfff7bfff (overdrive bit set — tuning works out of the box).

## Design consequence for the UI

v1 panels bind 1:1 to this surface:
- **Tuning**: OD_SCLK min/max sliders (Athena panel) + perf level dropdown
- **Performance**: temp / power / busy gauges (1 s poll)
- **System**: card info, clock-state table, driver/kernel version

Missing on Linux (no equivalent in sysfs): voltage curves, fan curve, in-app
replay, frame generation. Those panels get "not supported on this platform"
state in v1 — honest, and matches what Windows users on non-OD GPUs see.
