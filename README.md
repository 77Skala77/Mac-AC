# Mac AC Guard MVP

Mac AC Guard is a macOS menu bar MVP that helps a MacBook behave closer to "AC powered with the battery as reserve". It does not physically disconnect the battery. The MVP monitors AC/battery state, gates AC Guard mode behind safe conditions, delegates charge-limit control to a backend, records Battery Lab tests, and reports battery participation.

## Play Plugged In. Keep The Battery Near Its Limit.

Heavy workloads can pull serious energy through a MacBook battery. In our battery-only game test, the battery dropped from 70% to 49% in about 15 minutes. AC Guard is built for the opposite scenario: when your Mac is plugged in, it helps keep the battery near a chosen limit and lets the adapter handle the workload.

This is not about making the battery immortal. It is about reducing unnecessary battery participation during plugged-in heavy use.

## Feasibility

The safe MVP is feasible with public macOS power APIs and a conservative backend boundary:

- Power state can be read through IOKit Power Sources, IORegistry AppleSmartBattery, and `pmset` fallback.
- On Apple Silicon, practical charge-limit control is delegated to the external `batt` tool. The app never stores passwords and uses non-interactive `sudo -n` for privileged commands.
- On Intel, safe control is left as a skeleton because SMC/BCLM approaches vary by model and macOS version, and may require unsupported SIP changes.
- If charge-limit control is unavailable, the app continues as a monitor-only diagnostic tool.

## Architecture

- `PowerSourceMonitor`: reads AC/battery state with IOKit/IORegistry and graceful fallbacks.
- `ChargeLimitController`: backend protocol for availability, status, limit changes, lower-limit delta, and disable.
- `AppleSiliconBattBackend`: first Apple Silicon backend, wrapping `batt status`, `sudo batt limit`, and `sudo batt lower-limit-delta`.
- `IntelSMCBackend`: explicit skeleton; it does not perform unsafe changes.
- `MonitorOnlyFallbackBackend`: safe fallback when control is unavailable.
- `BackendDetector`: selects backend by architecture and availability.
- `BatteryLabRecorder`: records 5-second test samples to CSV and JSON.
- `ReportGenerator`: computes energy in/out, throughput, net change, drain rate, temperatures, averages, and Battery Participation Index.
- `ShellCommandRunner`: executes binaries without shell string interpolation, with stdout/stderr/exit-code capture and timeout.

## Real Device Test Results

Test device: MacBook Pro 16-inch 2024, Apple M4 Max, 140W Apple USB-C Power Adapter, MagSafe 3.

- AC Guard idle, 5 minutes: 70% to 70%, battery throughput `0 Wh`, Battery Participation Index `0 Wh`.
- Normal charging idle, 5 minutes: 70% to 76%, battery energy in `5.182265703106667 Wh`.
- AC Guard load/game, 15 minutes: 80% to 80%, battery throughput `0.0011711552411482068 Wh`.
- Normal charging load/game, 15 minutes: 83% to 94%, battery throughput `10.524986705215039 Wh`.
- Load/game comparison: participation reduction is about `99.99%`.

These results show that the charge-limit backend can dramatically reduce battery energy throughput during the tested workloads, but the result depends on adapter capacity, macOS behavior, `batt`, and workload conditions.

## Real Device Test: Heavy Game, 15 Minutes

On a MacBook Pro 16-inch M4 Max with a 140W MagSafe adapter, we ran a 15-minute heavy-game test from a 70% battery starting point.

Battery Only:

- Battery dropped from 70% to 49%.
- Battery delivered `17.49 Wh`.
- Average battery power: `-69.62 W`.

AC Guard:

- Battery stayed around the 70% target limit.
- Observed range: `70–71%`.
- Battery participation: `0.44 Wh`.
- Average battery power: `+1.24 W`.

Result:

- AC Guard reduced battery participation by about `97.5%` in this test.
- The comparison was `17.49 Wh` vs `0.44 Wh`.
- The battery-only run showed a `-21%` battery drop; the AC Guard run stayed within `1%` of the target limit.

These numbers are strong, but they are still test results, not universal promises. Mac AC Guard helps reduce battery participation; it does not guarantee a fixed percentage reduction in every workload.

## Homebrew batt Notes

Homebrew-installed `batt` is supported as the practical Apple Silicon backend. Mac AC Guard checks `/opt/homebrew/bin/batt`, `/usr/local/bin/batt`, then `PATH`.

Known Homebrew behavior:

- `sudo batt install --allow-non-root-access` may be unavailable for Homebrew-installed `batt`.
- `sudo brew services start batt` can still provide a working daemon.
- `Allow non-root users to access the daemon: ✘` is shown as a warning, not as monitor-only, if `batt status` works.
- Write commands still use non-interactive `sudo -n`; if they fail, the app reports the command to run manually and never asks for or stores a password.

## This App Does Not Physically Disconnect The Battery

Mac AC Guard does not physically disconnect the battery. It sets a charge limit when a safe backend is available, tracks whether the battery participates in power flow, records evidence, and falls back to monitoring if safe control is unavailable.

Mac AC Guard uses `batt` to control charging behavior on supported Apple Silicon Macs. Results depend on Mac model, adapter power, workload, temperature, macOS behavior, and `batt` availability. Battery percentages are rounded by macOS, so a configured 70% limit may appear as 70–71% in real use.

## Known Limitations

- A signed distributable `.app`, installer, Launch at Login, and privileged helper are intentionally outside this patch.
- Intel SMC/BCLM control remains a safe skeleton.
- Some IORegistry fields are model-dependent and may be unavailable.
- `batt` status refreshes can take time, so the UI verifies actual limits after write commands and may temporarily show "Command sent. Waiting for backend refresh."

## Risks And Boundaries

- `batt` output and command availability can vary by installed version.
- `sudo -n` fails if the user has not configured privileges or an active sudo timestamp; the app shows a readable error instead of prompting insecurely.
- Some telemetry fields, such as adapter watts, battery current, battery temperature, CPU/GPU load, and health, are not guaranteed on every Mac or macOS version.
- The MVP avoids SIP disabling, firmware/SMC modification, hidden privilege escalation, and any claim that the battery is physically disconnected.
- Swift Package builds and runs with Xcode/SwiftPM. A fully signed distributable `.app` bundle can be added as a packaging stage.

## Build And Run

```zsh
swift build
swift test
swift run MacACGuard
```

Xcode CLI:

```zsh
xcodebuild -scheme MacACGuard -destination 'platform=macOS' build
xcodebuild -scheme MacACGuard -destination 'platform=macOS' test
```

Open in Xcode:

```zsh
open Package.swift
```
