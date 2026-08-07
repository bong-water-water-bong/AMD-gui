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

v0.1 skeleton: Qt6 Quick shell with the CNext sidebar (Gaming / Tuning /
Performance / Display / System). Live backend on amdgpu sysfs:

- **Tuning**: Overdrive (pp_od_clk_voltage) min/max SCLK + perf level — reads
  work as user, writes need root (surfaced in-app)
- **Performance**: GPU temp / power / busy / VCN gauges, 1 s poll
- **System**: GPU info, clock states

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

## Roadmap

- [x] Extraction + binary specs (qm contexts, PDB map, string corpus)
- [x] sysfs backend probe + Qt6 shell skeleton with live metrics/tuning
- [x] Gaming page: game list + per-game profiles
- [x] Display page: screens/connectors/night light + Graphics feature matrix
- [ ] Root strategy for writes (polkit rule or small setuid helper)
- [ ] PDB deep-dive: AMDRSServ IPC names for the daemonized path

## License

AGPL-3.0. Original code only — no binary-lifted assets.
