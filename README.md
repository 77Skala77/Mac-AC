# Mac AC Guard MVP

Mac AC Guard is a macOS menu bar MVP that helps a MacBook behave closer to "AC powered with the battery as reserve". It does not physically disconnect the battery. The MVP monitors AC/battery state, gates AC Guard mode behind safe conditions, delegates charge-limit control to a backend, records Battery Lab tests, and reports battery participation.

## Play Plugged In. Keep The Battery Near Its Limit.

Heavy workloads can pull serious energy through a MacBook battery. In our battery-only game test, the battery dropped from 70% to 49% in about 15 minutes. AC Guard is built for the opposite scenario: when your Mac is plugged in, it helps keep the battery near a chosen limit and lets the adapter handle the workload.

This is not about making the battery immortal. It is about reducing unnecessary battery participation during plugged-in heavy use.

## Feasibility

The safe MVP is feasible with public macOS power APIs and a conservative backend boundary:

- Power state can be read through IOKit Power Sources, IORegistry AppleSmartBattery, and `pmset` fallback.
- On Apple Silicon, practical charge-limit control is delegated to the external `batt` tool. The app never stores passwords. This Swift Package build tries narrow, allowlisted direct `batt` operations and opens a permission/setup flow when daemon permissions require administrator authorization.
- On Intel, safe control is left as a skeleton because SMC/BCLM approaches vary by model and macOS version, and may require unsupported SIP changes.
- If charge-limit control is unavailable, the app continues as a monitor-only diagnostic tool.

## Architecture

- `PowerSourceMonitor`: reads AC/battery state with IOKit/IORegistry and graceful fallbacks.
- `ChargeLimitController`: backend protocol for availability, status, limit changes, lower-limit delta, and disable.
- `AppleSiliconBattBackend`: Apple Silicon read backend, wrapping `batt status` and delegating writes to a narrow write backend.
- `LocalBattBackend`: direct allowlisted `batt limit`, `batt lower-limit-delta`, and `batt adapter enable` operations. It never accepts arbitrary shell input.
- `PrivilegedHelperBackend`: production-ready protocol boundary for a signed helper with allowlisted operations only. The Swift Package build contains an honest unavailable client skeleton, not a fake installation.
- `ManualSetupCommandGenerator`: generates validated direct and `sudo` Terminal fallback instructions for the selected preset.
- `IntelSMCBackend`: explicit skeleton; it does not perform unsafe changes.
- `MonitorOnlyFallbackBackend`: safe fallback when control is unavailable.
- `BackendDetector`: selects backend by architecture and availability.
- `BatteryLabRecorder`: records 5-second test samples to CSV and JSON.
- `ReportGenerator`: computes energy in/out, throughput, net change, drain rate, temperatures, averages, and Battery Participation Index.
- `ShellCommandRunner`: executes binaries without shell string interpolation, with stdout/stderr/exit-code capture and timeout.

## First-time Permission Setup

Reading `batt status` works without elevated privileges when the daemon is available. Changing charge limits may require administrator authorization depending on the installed `batt` configuration.

Mac AC Guard does not store passwords, show a custom password prompt, or pipe credentials into `sudo`. If a direct allowlisted write fails because authorization is required, the app keeps the “Работа от сети” switch OFF and opens a permission/setup card.

The setup card provides:

- `Grant Permission`: explains that a one-time macOS authorization flow requires the signed privileged-helper packaging stage. The current Swift Package build does not pretend that helper installation succeeded.
- `Use Terminal Setup Instead`: keeps the safe manual fallback available now.
- `Copy Setup Commands`: copies validated `batt limit`, `batt lower-limit-delta`, `batt adapter enable`, and `batt status` commands.
- `Refresh Status`: reads status only. It never writes backend state.

After manual setup, choose `Refresh Status`. If `batt` reports an active upper/lower range such as `70/65`, the UI updates its selected limit and delta from the actual backend state.

## Security Model

- No password storage and no custom password-entry UI.
- No arbitrary shell execution. Executables and arguments are passed separately.
- App-side writes are allowlisted: supported limits are `30/40/50/60/70/80`, deltas are `2/5/10`, adapter mode can be enabled, and disable maps to `batt limit 100`.
- The helper protocol exposes only `healthCheck`, `getStatus`, `setChargeLimit`, `setLowerLimitDelta`, `enableAdapter`, and `disableLimit`.
- Raw Battery Lab JSON/CSV files are not modified or fabricated.
- Mac AC Guard does not physically disconnect the battery.
- Actual behavior depends on Mac model, adapter power, workload, temperature, macOS behavior, and `batt` availability.

## UI And User Flow

The compact menu-bar popover uses lightweight native SwiftUI materials for a translucent macOS utility appearance. The first screen stays focused on the one-click AC Guard switch. Detailed backend, permission, current, power, and raw `batt` fields live in Settings / Diagnostics.

The intended signed-app flow is one-time macOS authorization followed by one-switch AC Guard control. In the current Swift Package build, direct daemon writes work when permitted; otherwise the UI provides honest manual setup instructions instead of leaving the user with only a red `sudo` error.

## One-click Auto Guard

The main “Work from power adapter” switch is intentionally separate from the advanced manual charge-limit controls. It chooses a supported limit close to the current charge and applies a default `5%` lower-limit delta:

- `0...30%` -> `30%`
- `31...40%` -> `40%`
- `41...50%` -> `50%`
- `51...60%` -> `60%`
- `61...70%` -> `70%`
- `71...100%` -> `80%`

The safety gate still refuses activation below `30%`. The manual limit remains available through “Apply selected limit”, but it does not control the one-click Auto Guard switch.

## Live Power Monitoring

Mac AC Guard uses a lightweight read-only IOKit polling path to catch adapter changes while the popover remains open. Polling runs every `2` seconds while the popover is open or AC Guard is active/pending, and every `8` seconds in the background. Full `batt status` reads happen less frequently and writes are never triggered by live monitoring.

When the adapter is disconnected during an active or pending mode, the toggle turns off, the request is stopped, and an `acGuardStoppedAdapterDisconnected` event is logged. Reconnecting the adapter refreshes state but does not silently reactivate AC Guard.

## Language

Mac AC Guard supports Russian and English UI. The language can be changed in Settings. The selected language is saved locally and the interface updates immediately.

## Язык

Mac AC Guard поддерживает русский и английский интерфейс. Язык можно изменить в настройках. Выбранный язык сохраняется локально, интерфейс обновляется сразу.

## Menu Bar Controls

The app uses one AppKit menu-bar status item. Left-click opens the SwiftUI popover. Right-click opens a localized context menu with open, refresh, Battery Lab, diagnostics, and quit actions. Quit stops monitoring, flushes event logging, releases the single-instance lock, and terminates the app cleanly.

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
- Direct write commands are attempted without shell interpolation. If daemon authorization is required, the app opens a permission/setup card with manual commands and never asks for or stores a password.

## This App Does Not Physically Disconnect The Battery

Mac AC Guard does not physically disconnect the battery. It sets a charge limit when a safe backend is available, tracks whether the battery participates in power flow, records evidence, and falls back to monitoring if safe control is unavailable.

Mac AC Guard uses `batt` to control charging behavior on supported Apple Silicon Macs. Results depend on Mac model, adapter power, workload, temperature, macOS behavior, and `batt` availability. Battery percentages are rounded by macOS, so a configured 70% limit may appear as 70–71% in real use.

## Known Limitations

- A signed distributable `.app`, installer, Launch at Login, and production privileged-helper installation remain a packaging stage. The helper API skeleton is present, but the Swift Package build does not claim it is installed.
- Intel SMC/BCLM control remains a safe skeleton.
- Some IORegistry fields are model-dependent and may be unavailable.
- `batt` status refreshes can take time, so the UI verifies actual limits after write commands and may temporarily show "Command sent. Waiting for backend refresh."

## Risks And Boundaries

- `batt` output and command availability can vary by installed version.
- Direct writes can fail if daemon access is restricted. The app opens a readable permission/setup flow instead of prompting insecurely.
- Some telemetry fields, such as adapter watts, battery current, battery temperature, CPU/GPU load, and health, are not guaranteed on every Mac or macOS version.
- The MVP avoids SIP disabling, firmware/SMC modification, hidden privilege escalation, and any claim that the battery is physically disconnected.
- Swift Package builds and runs with Xcode/SwiftPM. A fully signed distributable `.app` bundle can be added as a packaging stage.

## Production Privileged Helper Packaging

The helper boundary is intentionally narrow and ready for a signed bundle stage. A production release should add an app target, helper target, launchd property list, code-signing identities, designated-requirement validation, and XPC connection checks before enabling helper installation. The helper must resolve only `/opt/homebrew/bin/batt` or `/usr/local/bin/batt`, validate every preset and delta, log every privileged operation, and reject raw shell commands.

Until that signed packaging exists, the Swift Package build reports that the helper needs installation and keeps the manual Terminal fallback available.

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

## Build Installable App

Create a local `.app` bundle and a DMG:

```zsh
./scripts/package_app.sh
./scripts/create_dmg.sh
```

The app bundle is created at:

```text
dist/Mac AC Guard.app
```

The disk image is created at:

```text
dist/MacACGuard.dmg
```

`package_app.sh` performs a release build, wraps the executable and SwiftPM resource bundle in a standard macOS app bundle, writes `Info.plist`, and applies an ad-hoc signature when `codesign` is available.

## Distribution Limitations

- Local ad-hoc builds may trigger a Gatekeeper warning on another Mac.
- A production release requires an Apple Developer ID Application certificate.
- Smooth distribution requires notarization and stapling.
- The final privileged-helper install flow also requires signed app/helper targets, launchd packaging, and designated-requirement checks.
- The current DMG is suitable for local testing and manual installation, not a notarized public release.
