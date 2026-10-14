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
whole flow without touching anything real. User-verified end to end (2026-10-11):
real iPhone → folder transfer + real Mac-library export.

## Install (beta DMG)

This is beta software: it is not sold in the App Store and it is not
"notarized" with Apple, so your Mac's Gatekeeper will ask once whether you
trust it. That's expected — follow the steps below exactly and first launch
works.

### Installing on a new Mac (your family, or you on another Mac)

1. Open the downloads page: **<https://github.com/MaksimZinovev/offload/releases>**
2. Click the release named **“Offload 0.1.0 — family beta”** and download
   **Offload-0.1.0.dmg** (the download link is under “Assets” — the small
   triangle if it is folded closed).
3. Find the downloaded file in **Downloads** (Dock, or Finder → Downloads).
4. Double-click **Offload-0.1.0.dmg**. A window opens showing the
   **Offload** app icon.
5. In that window, **drag the Offload icon onto the Applications folder**
   (this copies it to your Mac — the normal install step).
6. Close the DMG window and **eject** the disk “Offload” (Finder sidebar →
   Eject symbol). You don't need the DMG file any more.
7. Open **Applications** (Finder sidebar or Launchpad), find **Offload** —
   then **hold Control and click** it (or right-click) and choose **Open**.
8. A Gatekeeper dialog appears (“…can't verify…”). Click **Open** again.
   You only have to do this once — every later launch opens normally.
9. The app starts in **demo mode**: a pretend phone with sample photos, so
   you can safely click through all 7 screens before touching real data.

If a launch is still blocked after step 8, paste this one line into
Terminal (Applications → Utilities → Terminal) and press Return — then
open Offload like any normal app:

```sh
xattr -dr com.apple.quarantine /Applications/Offload.app
```

The same instructions ship inside the DMG as **“Read Me.rtf”**.

### Building the installer yourself (developer path)

```sh
sh scripts/make-dmg.sh    # -> dist/Offload-0.1.0.dmg (app + Read Me.rtf, ad-hoc signed)
```

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