# AMD-gui

A native Linux re-implementation of AMD Adrenalin (Radeon Software) —
give AMD Linux users the control surface Windows users get.

Built from a full extraction of the factory Windows image of this machine
(Strix Halo, Ryzen AI Max+ 395 / Radeon 8060S): appx 10.24.20021.0, Qt6 CNext
UI, debug symbols. Specs derived from the binaries live in `spec/`:

- `ui-inventory.md` — the four CNext variants and the consumer panel set
- `pdb-architecture.md` — MVC architecture + full feature inventory
- `strix-halo-backend.md` — verified sysfs data surface on this box
- `strings-corpus.txt` — 60k UI strings extracted from RadeonSoftware.exe
- `localisation/` — decoded .qm panel contexts
- `pdb-modules.txt` — 1103 object files (module list)

## Status

v0.3 Qt6 Quick shell with the CNext sidebar (Gaming / Tuning /
Performance / Display / System). Live backend on amdgpu sysfs:

- **Tuning**: Overdrive (pp_od_clk_voltage) min/max SCLK + perf level — reads
  work as user, writes need root (surfaced in-app). **Power limit**
  (power1_cap, 221–340 W on this board) applies from the Custom slider.
- **Performance**: GPU temp / junction / mem / power / busy / VCN gauges,
  1 s poll, plus **per-process GPU activity** (DRM fdinfo: engine time
  deltas + per-process VRAM, like Adrenalin's GPU Activity tab) and
  VRAM used / mem-busy gauges.
- **System**: GPU info, VRAM used/total, kernel, fan, power cap, temps,
  clock states

Gaming/Display pages are placeholders. In-app replay, fan curve, voltage
curves have no sysfs equivalent on this platform — they stay "not supported".

## Build

```sh
sudo apt install qt6-base-dev qt6-declarative-dev \
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
build/amd-gui --selftest   # parsing logic check, no GPU needed
build/amd-gui              # run
```

## .deb package

```sh
scripts/build-deb.sh              # -> amd-gui_<ver>_amd64.deb
sudo apt install ./amd-gui_*.deb  # install
```

The package installs the binary, desktop entry and icon; its `postinst` also
installs the tmpfiles rule + power-profiles-daemon drop-in so tuning writes
work for the `video` group (same as `scripts/install-permissions.sh`).

## Roadmap

- [x] Extraction + binary specs (qm contexts, PDB map, string corpus)
- [x] sysfs backend probe + Qt6 shell skeleton with live metrics/tuning
- [x] Gaming page: game list + per-game profiles
- [x] Display page: screens/connectors/night light + Graphics feature matrix
- [x] Root strategy for writes (tmpfiles rule + video group + PPD block)
- [x] Power limit control + per-process GPU activity (fdinfo) — v0.3
- [ ] PDB deep-dive: AMDRSServ IPC names for the daemonized path

## License

AGPL-3.0. Original code only — no binary-lifted assets.
