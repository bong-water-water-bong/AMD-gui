# AMD Adrenalin Edition — Full GUI Capture & Strix Halo Replication Map

**Target hardware:** AMD Ryzen AI MAX+ 395 w/ Radeon 8060S (Strix Halo, gfx1151), PCI 1002:1586
**Context:** GPU renders host-side (Linux `amdgpu` + virglrenderer); WinBoat guest sees only a virtio-gpu "Helios" adapter. Adrenalin (Windows-only) cannot run in the guest — this capture inventories its ENTIRE UI so every function can be reproduced where the hardware actually lives (the host).
**Status legend:** ✅ replicable now · 🟡 partial/approximation · ❌ not possible on this hardware/architecture
**Sources:** AMD Software: Adrenalin Edition product pages, XDA complete guide (Mar 2024), AMD Performance Tuning docs, driver-level feature knowledge, live sysfs inspection of this box.

---

## 1. Top-level navigation tree

```
AMD Software: Adrenalin Edition
├── Home
├── Gaming
│   ├── Games
│   ├── Graphics
│   ├── Display
│   ├── Hybrid Graphics          (only on multi-GPU systems)
│   └── Advisors
├── Record & Stream  (Radeon ReLive; hidden on unsupported GPUs)
│   ├── Record
│   ├── Live Stream
│   ├── Scene Editor
│   ├── Media
│   └── Settings
├── Performance
│   ├── Metrics
│   ├── Tuning
│   └── Settings
├── Settings (gear)
│   ├── System
│   ├── Audio & Video
│   ├── Hotkeys
│   ├── AMD Link
│   └── Preferences
└── [Radeon Overlay — in-game, Ctrl+Shift+O]
```

---

## 2. Home

| Control | Type | Notes | Map |
|---|---|---|---|
| Recently played games | Cards | icon, name, hours, avg FPS | ✅ feed from guest/game logs |
| Driver version card | Info | shows installed driver | ✅ host: `amdgpu` / `modinfo amdgpu` |
| AMD Link status | Info | remote-stream server state | ✅ Sunshine/Moonlight status |
| Tutorials / ads carousel | Cards | marketing | 🟡 optional |

---

## 3. Gaming

### 3.1 Games
- Grid of detected games: name, hours played, average FPS over playtime.
- Per-game profile page: **Launch** button, per-game graphics overrides (same controls as §3.2, applied per-app), "Reset to Defaults".

### 3.2 Graphics (global, applies to all games)

| Control | Type | Range / Default | Map |
|---|---|---|---|
| Graphics profile preset | Dropdown | Standard / Quality / Performance / Custom | 🟡 per-game env presets (gamescope/mangohud config) |
| Radeon Super Resolution (RSR) | Toggle | — | 🟡 gamescope FSR upscaling |
| RSR Sharpness | Slider | 20–100% (default 80%) | ✅ gamescope `--fsr-sharpness` |
| Radeon Anti-Lag / Anti-Lag 2 | Toggle | — | ❌ driver-level latency control; nearest: MAILBOX present mode / low-latency swapchain |
| Radeon Boost | Toggle | — | ❌ dynamic-res-on-motion; game-side only |
| Boost min/max resolution | Sliders | % | ❌ |
| Radeon Chill | Toggle | — | 🟡 fps limiter (gamescope `--fps-limit`, mangohud `fps_limit`) |
| Chill Min FPS | Slider | 0–max | ✅ fps cap |
| Chill Max FPS | Slider | 0–max | ✅ fps cap |
| Radeon Image Sharpening | Toggle | — | ✅ CAS via Vulkan layer / gamescope |
| Image Sharpening amount | Slider | 0–100% (default 80%) | ✅ CAS strength |
| Radeon Enhanced Sync | Toggle | — | 🟡 swapchain MAILBOX/immediate vsync off |
| AMD Fluid Motion Frames (AFMF) | Toggle | — | ❌ driver frame-gen; not on virtio/RDP path |
| AFMF Search for frames | Dropdown | Auto / On / Off | ❌ |
| AFMF Performance mode | Toggle | — | ❌ |
| **Advanced (collapsed):** | | | |
| Frame Rate Target Control | Toggle + slider | max FPS | ✅ gamescope `--fps-limit` |
| Tessellation Mode | Dropdown | Use app / Override AMD opt. / Enhance | 🟡 env knob (rarely used today) |
| OpenGL Triple Buffering | Toggle | — | ✅ mesa `vblank_mode` |
| 10-bit Pixel Format | Toggle | — | ❌ RDP/virtio path |
| Texture Filtering Quality | Dropdown | High/Standard | ✅ mesa `R600_DEBUG`/`MESA_*` (negligible) |
| Surface Format Optimization | Toggle | — | ❌ legacy |
| Wait for Vertical Refresh | Dropdown | Off/Always On/App-controlled | ✅ mesa `vblank_mode` |
| Shader Cache | Dropdown | AMD Optimized / On / Off | ✅ mesa shader cache env + `~/.cache/mesa_shader_cache` |
| Reset Shader Cache | Button | — | ✅ `rm -rf ~/.cache/mesa_shader_cache` |
| Reset to Factory Defaults | Button | — | ✅ restore config |

### 3.3 Display

| Control | Type | Range / Default | Map |
|---|---|---|---|
| AMD FreeSync | Toggle | — | ❌ headless host + RDP; no VRR path |
| FreeSync Premium Pro | Toggle | — | ❌ |
| Custom Resolution | Toggle + W×H | — | ✅ guest RDP resolution / virtio modes |
| Display Scaling | Dropdown | Preserve aspect / Full panel / Center | 🟡 virtio-gpu edid |
| GPU Scaling | Toggle | — | ❌ RDP |
| Virtual Super Resolution (VSR) | Toggle | — | 🟡 gamescope internal res > output |
| Color Depth | Dropdown | 6/8/10 bpc | ❌ RDP |
| Pixel Format | Dropdown | RGB 4:4:4 / YCbCr 4:4:4 / 4:2:2 / 4:2:0 | ❌ RDP |
| Color Temperature | Slider | 4000–10000 K (default 6500) | ✅ drm CTM / `wlr-gamma` / gamescope |
| Brightness | Slider | — | ✅ gamescope / compositor |
| Contrast | Slider | — | ✅ drm CTM matrix |
| Saturation | Slider | — | ✅ drm CTM matrix |
| Hue | Slider | — | ✅ drm CTM matrix |
| HDR | Toggle | — | ❌ headless/RDP |
| Rotate Display | Dropdown | 0/90/180/270 | ✅ `wlr-randr` transform / gamescope |
| Eyefinity (span) | Setup | multi-display | ❌ headless |

### 3.4 Hybrid Graphics — ❌ N/A (single GPU in box)

### 3.5 Advisors
- **Performance Advisor**: auto-scan → enables recommended settings (Enhanced Sync etc.).
- **Radeon Advisor**: per-game recommendations (fps, settings).
- Map: 🟡 custom advisor script over `amdgpu_top`/mangohud logs + per-game hints.

---

## 4. Record & Stream (ReLive)

> On APUs ReLive is often unsupported — irrelevant for us anyway: the guest renders through virtio, so capture belongs to **OBS** (host or guest).

| Tab | Contents | Map |
|---|---|---|
| Record | REC button, preview, resolution/FPS/quality, mic, camera | ✅ OBS |
| Live Stream | platform (Twitch/YT/FB), stream key, quality, bitrate, scenes, chat | ✅ OBS |
| Scene Editor | scenes/layers: screen, camera, mic, text | ✅ OBS |
| Media | gallery of recordings/screenshots | ✅ OBS/`obs-studio` media dir |
| Settings | output folder, quality presets (Low/Med/High/Ultra), resolution, FPS 30/60, bitrate, codec H.264/HEVC/AV1, **Instant Replay** (toggle, 5s–10min), audio capture mode, **AMD Noise Suppression** toggle, stream server/bitrate, hotkeys | ✅ OBS (replay buffer, RNNoise, AV1 via VA-API on 8060S) |

---

## 5. Performance

### 5.1 Metrics
- Live graphs: GPU usage, VRAM usage, CPU usage, RAM, FPS, frame time, temp, fan speed, power, clock.
- Toggles per metric; sampling interval 1–5 s; overlay position; **log to CSV** (toggle + path); hide overlay while logging.
- Map: ✅ `amdgpu_top` (reads `gpu_metrics`, hwmon, `gpu_busy_percent`, `mem_info_*`), mangohud in-guest/host, CSV via `amdgpu_top -l` or sysfs poll script.

### 5.2 Tuning

**One-click / presets**
| Control | Type | Map |
|---|---|---|
| Auto Overclock GPU | Button | ❌ no auto-OC; manual SCLK only |
| Auto Undervolt GPU | Button | ❌ voltage not exposed (no OD_VDDC) |
| Overclock VRAM | Button | ❌ no MCLK OD (unified memory) |
| Quiet / Balanced / Rage | Preset cards | ❌ presets; DPM level partial (`power_dpm_force_performance_level`) |
| Stress Test | Button | ✅ `vkmark --present-mode=headless` (verified: 74% busy, 2900 MHz, 79 W under load) |
| Resizable BAR | Toggle | 🟡 platform firmware setting, fixed |
| GPU Recovery / Reset | Button | ✅ `echo manual`… / reboot |

**Custom — GPU**
| Control | Type | Range / Default | Map |
|---|---|---|---|
| GPU Min Frequency | Slider | ~500–2900 MHz | ❌ SMU locked — write to `pp_od_clk_voltage` returns EINVAL (verified live). UI shows range read-only |
| GPU Max Frequency | Slider | ~500–2900 MHz | ❌ same — OD interface rejects all writes on this APU |
| Voltage | Slider | mV | ❌ not exposed |
| Power Limit | Slider | −50%…+X% | ❌ no `power1_cap` |
| Temperature Limit | Slider | °C | ❌ not exposed |

**Custom — VRAM** (all ❌ — Strix Halo uses unified memory; no MCLK/VRAM voltage/timing OD)

**Custom — Fan**
| Control | Type | Map |
|---|---|---|
| Fan Tuning master | Toggle | ❌ no pwm in hwmon (platform fans) |
| Max Fan Speed | Slider % | ❌ |
| Min Acoustic Limit | Slider % | ❌ |
| Min Fan Speed | Slider % | ❌ |
| Zero RPM | Toggle | ❌ |
| Custom fan curve (drag points) | Graph | ❌ |

**Profiles**
| Control | Map |
|---|---|
| Save profile | ✅ sysfs value file (e.g. `/etc/winboat/gpu-profile`) |
| Load profile | ✅ apply script |
| Share/import | ✅ file copy |
| Apply / Reset | ✅ script |

### 5.3 Performance → Settings
- Sampling interval, overlay position, log location, hide overlay while logging → ✅ amdgpu_top/mangohud config.

---

## 6. Settings (gear)

### 6.1 System
Driver version/info ✅ (`modinfo amdgpu`, `fw_version`), Check for Updates ✅ (package manager), auto-update toggle ✅ (unattended-upgrades), factory reset ✅, export/import settings ✅ (config file), bug report ✅ (logs), system info ✅.

### 6.2 Audio & Video
- **AMD Noise Suppression** (input + output) → 🟡 OBS RNNoise / pipewire noise suppression / guest-side app.

### 6.3 Hotkeys
Full hotkey table (toggle overlay `Ctrl+Shift+O`, toolbar, record, instant replay, screenshot, stream, mic, camera, region record/stream, Boost, Chill, rotate display) — ✅ remappable via keybinds in OBS/mangohud/gamescope config.

### 6.4 AMD Link
Remote streaming to phone: ✅ **Sunshine + Moonlight** (host renders, streams to any client). Pairing code = Sunshine PIN.

### 6.5 Preferences
- Radeon Overlay on/off → ✅ mangohud toggle
- Ads on Home → ✅ trivial
- Language dropdown → ✅ i18n
- Launch on startup → ✅ systemd/autostart
- Toast notifications → ✅ notify-send
- Experimental features toggle → ✅ env-flag

---

## 7. Radeon Overlay (in-game, Ctrl+Shift+O)

| Item | Map |
|---|---|
| Performance monitoring panel (FPS, frame time, temp, clocks) | ✅ mangohud |
| Overlay position/transparency | ✅ mangohud config |
| Record / Instant Replay / Screenshot | ✅ OBS hotkeys / mangohud screenshot |
| Chill toggle | ✅ fps-limit hotkey (gamescope) |
| Boost toggle | ❌ |
| Image Sharpening + slider | ✅ CAS via Vulkan layer |
| FreeSync / Enhanced Sync / Anti-Lag / AFMF toggles | ❌ / 🟡 / ❌ / ❌ |

---

## 8. Feature-parity verdict for THIS box (Strix Halo 8060S)

| Adrenalin function | Verdict | Replacement |
|---|---|---|
| Metrics + overlay + logging | ✅ full | amdgpu_top, mangohud, sysfs CSV |
| GPU min/max clock | ✅ full (same 600–2900 MHz range) | `pp_od_clk_voltage s 0/1` |
| FPS limits / Chill | ✅ | gamescope `--fps-limit` |
| Sharpening / RSR | ✅ | CAS / gamescope FSR |
| Recording / streaming / replay | ✅ | OBS (AV1 via VA-API) |
| Remote play (AMD Link) | ✅ | Sunshine + Moonlight |
| Noise suppression | 🟡 | OBS RNNoise / pipewire |
| Shader cache control | ✅ | mesa cache + env |
| Profiles save/load/share | ✅ | sysfs config scripts |
| Stress test | ✅ | glmark2 / vkmark |
| Color tuning (temp/bright/sat/hue) | 🟡 | drm CTM / gamescope |
| Advisors | 🟡 | custom log-analysis script |
| Anti-Lag / Boost / Enhanced Sync / AFMF / frame-gen | ❌ | driver-level, Windows-only; game-side FSR only |
| Voltage / power limit / temp limit / fan curve / VRAM OC | ❌ | not exposed by amdgpu on this APU |
| FreeSync / HDR / 10-bit / VSR / GPU scaling | ❌ | headless host + RDP/virtio path |

**Bottom line:** of Adrenalin's ~60 controls, ~35 are fully or closely replicable on the host via amdgpu sysfs + gamescope + OBS + mangohud; ~10 approximate; ~15 are Windows-driver-only or physically absent (no fan/voltage/power rails exposed, no display output, RDP instead of native scanout). GPU min/max clock sliders are displayed read-only: the SMU on this APU rejects `pp_od_clk_voltage` writes (EINVAL, verified).

**Replica UI built:** `/home/bcloud/AMD-gui/app/` — `start.sh` serves an Adrenalin-styled web UI on `http://localhost:8080` (backend `adrenalin_server.py`, stdlib only). Live: DPM level (auto/low/high/manual, sudo -n sysfs write), live metrics (busy/sclk/temp/power/VRAM/GTT), vkmark headless stress test with stop, mesa shader-cache reset, profiles save/load/delete, settings export/import, in-browser CSV logging. Locked/Windows-only controls render as Adrenalin does but greyed with a reason.
