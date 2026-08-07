# AMD-gui — UI inventory from the extracted Adrenalin (CNext)

Extracted from the factory Windows image of this machine (Strix Halo, Ryzen AI
Max+ 395 / Radeon 8060S), appx version 10.24.20021.0, driver 32.0.12064.27
(24.20.64 family). Raw material on ryzen (`192.168.50.185`):
`~/onnx-extract/windows/amd-adrenalin/`. See `ADRENALIN-LINUX-PORT.md` there
for the full architecture writeup.

Sources used here:
- `spec/localisation/*.ts` — decoded Qt `.qm` translation files (4 per locale;
  these are the CNext panel contexts and their UI strings). The `.qm` files
  carry a non-standard 16-byte header but Qt5 `lconvert` decodes them as-is.
- `spec/strings-corpus.txt` — 60,460 UTF-16 strings from `RadeonSoftware.exe`
  (33.8 MB binary, Qt6).

## The four UI variants

| File | Audience | Panels (Qt contexts) |
|---|---|---|
| `CNext_WS` | Adrenalin (consumer) | Gaming, GameList/GamePage/GameProfile/GameSearchBar, GameStreamingSetting, GamingNavMenu, Hotkeys, DvrSettingsMedia/DvrSettingsRecording (in-game replay), GalleryListMenu, PerformanceSetting, Tuning, System/SystemInfo, PreferencesSetting, SidebarNavMenu, TopBar, Notifications, WindowChrome, Wizard, ReliveWizard, YoutubeTermsDialog, LastPlayed/RecentGames/NowPlaying |
| `CNext_EMBD` | Embedded/PRO | WS set + Display, Eyefinity, Graphics, OverdriveNext, Radeon3d, VirtualResolution, Infocenter, PrefMenu, AppView, GameDetails, GameEyefinity, Style3 |
| `CNext_VDI` | Virtual desktop | BasicGraphicsSettings, TuningCPU, DriverUpdateContent, WizardWelcome, Infocenter, Hotkeys — minimal |
| `CNext_CRTR` | (legacy CRT) | Same minimal set as VDI |

Port target: the **WS** panel set (the consumer surface), with EMBD's
Display/OverdriveNext as the tuning core — that's "give users control".

## Feature surface (from corpus + contexts)

- **Performance/Tuning**: GPU clocks, voltage curves (`VOLTAGE_GPUCLOCK_ABS`,
  `VOLTAGE_MEMORYCLOCK_ABS`), fan curve ("GPU %d Fan Curve Settings %d"),
  power limit, one-click auto-overclock (autoOverclockModel), per-GPU +
  per-application tuning
- **Metrics**: GPU/CPU voltage recording (`RecordGPUVoltage`), status logging
- **Gaming**: game list, per-game profiles, search, stats grid, streaming
  settings, hotkeys (RSX overlay)
- **Capture**: in-game replay (DvrSettings), GIF/video saving, gallery
- **Display**: Eyefinity multi-display, virtual resolution
- **System**: info, driver update, preferences, notifications, tray

## Linux mapping (updated from the ryzen doc)

| CNext piece | Linux equivalent | Status |
|---|---|---|
| Tuning (clocks/voltage/fan) | sysfs + `ryzenadj` (Strix Halo) | kernel-side exists; UI missing |
| PerformanceSetting metrics | amdgpu sysfs, `amdgpu_top`, amd-smi (ROCm) | exists; UI missing |
| Display/Eyefinity | kscreen/wlr-randr | exists; UI missing |
| Gaming profiles | per-app config, MangoHud presets | needs the UI shell |
| Capture/replay | wlroots screen copy, gpu-screen-recorder | exists; UI missing |
| Hotkeys overlay | compositor shortcuts | needs the UI shell |

The port is a **Qt6 UI + sysfs/amdgpu backend** project, not a driver project.
UI strings for the shell can be lifted from `strings-corpus.txt` (they are
AMD's own copy; keep the license question in mind — original work, not
binary-lifted, is the safe default for shipping).

## Next steps

1. Read the PDB (`RadeonSoftware.pdb`, 180 MB on ryzen) for the service/UI
   class map — the data paths between AMDRSServ.exe and the panels.
2. Backend probe: enumerate what Strix Halo exposes in sysfs (clocks, power,
   fan, voltage) — the real data surface the UI binds to.
3. Qt6 Quick shell skeleton with the WS sidebar (Gaming / Tuning /
   Performance / Display / System) wired to a sysfs backend.
