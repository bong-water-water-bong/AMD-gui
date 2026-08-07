# AMD-gui — architecture map from RadeonSoftware.pdb

`llvm-pdbutil` dump of `RadeonSoftware.pdb` (180 MB, not stripped, 1406
streams, 1103 unique .obj files, Qt 6). Full module list:
`spec/pdb-modules.txt`.

## Architecture: MVC triplets

Every CNext feature is a `xxxmodel.obj` + `xxxcontroller.obj` (+ `xxx.obj`)
triplet, with Qt meta-object (`moc_xxxmodel.obj`) + QML-side files. The
models are the data contracts — the Linux port's backend must expose the
same fields.

## Full feature inventory (from models/controllers)

**Display** — bluelightreduction, colordepth, colorenhancement, colormapping,
customcolor, customresolution, displaylist, displaymodel, displayoverrides,
displaysettings, displayspecs, edid, freesync + freesynccac + freesyncpo +
freesyncoloraccuracy, gpuscaling, hdcp, hdmilinkassurance, hdmiscaling,
integerscaling, pixelformat, virtualresolution

**Performance/tuning** — gpumodel, cpumetrics, cpumetricsettings, metrics,
perfmetric, perfmetriclist, perfmetricsmonitor, perfsettings, **pmf**
(Platform Management Framework — power/thermal policy), athena (clock/voltage
tuning, "Athena" = the overclocking subsystem), ecc (ECC toggle), chill,
boost

**Capture/stream** — dvrcommand, dvrdesktoplist, dvrfeature, dvrmic,
dvrsettings, dvrstreaming, galleryedit, easyrender, framegen (AFMF frame
generation), framegenwizard, framegenstatus

**Gaming** — gamemodel, gamecompatibility, gameprofile, hotkeys, appprofile
manager, game config parser (GameConfigParserLIB)

**System/UX** — appconfig, appview, launcher, newsfeed, notification,
privacy, driverupdateui, eula, exportimport, miscpreference, misctools,
coolermasterrgbled (RGB lighting), camera, audio, videoupscale,
analyticsdatastorage

## What this means for the port

- The Linux app = **Qt models with identical field names** + controllers
  calling sysfs/amdgpu instead of ADLX/AMDRSServ.
- ADLX (ADLXHelper.obj, adl.obj) is AMD's driver-API layer on Windows — its
  Linux analogue is sysfs + amdgpu + k10temp + ryzenadj.
- "Athena" is the internal name for the tuning/overclock subsystem
  (athenamodel.obj, AthenaIDs.obj) — the equivalent of pp_od_clk_voltage.

## Next

- Dump globals (`-globals`) for the AMDRSServ IPC message names if the
  service protocol matters — only needed once the UI needs live metrics from
  a daemon; for v1, the UI can read sysfs directly.
