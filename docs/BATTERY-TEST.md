# Battery acceptance test

Short Activity Monitor samples measure resource use, not app-specific battery drain. Do not interpret the whole-Mac charge change or remaining-time estimate as MechaKeys consumption.

1. Disconnect power and verify `ExternalConnected = No` using `ioreg -r -c AppleSmartBattery`. Keep brightness, Bluetooth devices, volume and background apps unchanged across runs.
2. Leave keyboard and mouse untouched for at least 40 seconds with sounds enabled. Check `pmset -g assertions` before interacting again. MechaKeys' audio assertion should clear after its 30-second idle deadline. Any typing/clicking or route change invalidates this idle trial.
3. Record app CPU, memory, Energy Impact and wakeups in Activity Monitor. Repeat with sounds off, normal typing, and repeated hover. Report helper processes separately.
4. Compare repeated 30–60 minute runs on battery: MechaKeys running versus quit, using the same typing/media workload. Alternate order. Record start/end charge, elapsed time, and whether the system slept or changed audio routes. Do not stop other apps without permission.
5. A consistent excess over baseline suggests further investigation; one percentage-point difference over a short run is inconclusive. Confirm the notch remains responsive after long idle and that sound resumes without a backlog.

No battery-life percentage guarantee is made. Bluetooth pause/resume has user confirmation. Previous short observations found low CPU/memory; the long A/B comparison remains outstanding.

## Live idle result — September 5, 2026

Running installed version: 2.10.1, PID 30118 (the updater build was not installed yet). At 12:34:02 EDT, CoreAudio held an output sleep assertion for MechaKeys. After a user-confirmed 45-second no-input pause, the 12:34:57 reading showed no MechaKeys/CoreAudio assertion. WindowServer reported the last input 63 seconds earlier; battery hardware reported `ExternalConnected = No` and `IsCharging = No`. This confirms release of the audio sleep assertion during inactivity, not total system sleep or an app-specific watt/battery percentage measurement. Build tests were running separately, so whole-Mac discharge readings are unsuitable for estimating MechaKeys consumption.
