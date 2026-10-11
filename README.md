# Offload

A one-button Mac app that offloads photos from your **iPhone** to a folder on
your Mac. Plug the phone in via USB, click through seven simple steps, and
your photos and videos land in the destination folder. **Nothing is deleted
from the iPhone** — offload, not destruct.

Built on [PhotosExport](https://github.com/MaksimZinovev/PhotosExport) for
Apple Photos library access, plus direct USB device import via
ImageCaptureCore.

## Status

**Family beta.** SwiftUI wizard (7 screens), real engine and real device IO
behind feature flags; a demo/mock mode is the default so you can explore the
whole flow without touching anything real.

## Quickstart

**Requirements:** macOS 13+ · Swift 6 toolchain (Xcode or Command Line
Tools) · for real iPhone import: an iPhone + USB cable.

### Demo mode (default — no device, no library touched)

```sh
swift run
```

Walk the whole 7-screen wizard against simulated data. A "Connected - test
it" button on step 3 simulates plugging in the phone.

### Real iPhone import (the product)

```sh
sh scripts/make-app.sh                                  # build + assemble .build/Offload.app
OFFLOAD_DEVICE=real .build/Offload.app/Contents/MacOS/Offload
```

- Keep the phone **unlocked and plugged in**; trust the prompts on the phone.
- "The last 10 photos" = the 10 newest on the phone; year checkboxes filter
  by capture date.
- Exports land at `<picked-folder>/Offload/YYYY/MM/` with the camera's
  native filenames (Live Photo jpg+mov pairs stay together).
- Failed transfers are logged, never silently skipped: `<target>/export_errors.log`
  (only written when something failed).

### Real export from the Mac's Photos library

```sh
sh scripts/make-app.sh
OFFLOAD_ENGINE=real OFFLOAD_DEVICE=off .build/Offload.app/Contents/MacOS/Offload
```

Reads the **system photo library** (the one designated in
Photos → Settings → General). Exports at `<picked-folder>/Offload/YYYY/MM/`.

## Development commands

| Command | What it does |
| --- | --- |
| `swift build` | Build (debug) |
| `swift run` | Run the app in demo (mock) mode |
| `sh scripts/make-app.sh` | Build + assemble `.build/Offload.app` (bundle identity) |
| `swift package clean` | Clean build artifacts (disk is tight) |

Real-vs-mock gates (read once at launch, unset/other = mock):

| Env var | Real mode |
| --- | --- |
| `OFFLOAD_DEVICE=real` | Live iPhone over USB (ImageCaptureCore): discovery, counts, download |
| `OFFLOAD_ENGINE=real` | Real export engine (`PhotosExportCore`) for the Mac Photos library |

Precedence: device → engine → mock (the phone is the photo source; the
Mac-library engine applies only in `OFFLOAD_DEVICE=off`).

## Troubleshooting

- **Step 1 says "none" though the phone is connected** — is the phone
  unlocked? A locked phone still lists, but won't transfer
  (`-9943 "Please unlock"`). Also: launch the **bundle binary**, not a stale
  copy — after code changes re-run `sh scripts/make-app.sh`.
- **Real library mode exports 0, no prompt** — a bare (non-bundle) binary
  gets PhotoKit "authorized-but-empty" silently; always launch via
  `.build/Offload.app`. Also check which library is *designated* in
  Photos → Settings → General — PhotoKit reads the system library only.
- **Counts stay 0 while enumerating** — the device catalog lands in one
  batch (`deviceDidBecomeReady(withCompleteContentCatalog:)`); on large
  camera rolls give it a moment.

## Architecture (short)

- `WizardModel` — one observable state machine: 7 steps, gates, env flags,
  the three-way export branch (device → engine → mock)
- `DeviceSource` — the only ImageCaptureCore import: device browser, session,
  `mediaFiles` catalog, sequential per-item downloads
- `MockEngine` — demo event engine mirroring the real call shape
- `PhotosExportCore` (SPM, tag `v0.1.0`) — the real Photos-library engine
- Screens: `Sources/Offload/Screens/*.swift` (one view per wizard step)

## Privacy

Everything runs locally; nothing leaves your machine. The iPhone copy path
reads items only — deletion from the phone comes in a later release and is
inert (demo) today.

## Roadmap

- Style pass · real counts in the estimate lines (fiction→real bridge) ·
  family beta DMG · notarized release