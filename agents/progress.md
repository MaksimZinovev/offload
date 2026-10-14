# Session Progress Log

## Current State

**Last Updated:** 2026-10-11 late evening (local)
**Session:** pi (offload-rooted, `~/repos/offload`) · review surface: sideshow `A6EP5Tpv46g` — "PhotosExport — friendly version" (localhost:8228)
**Active Feature:** Offload v1 (family beta) — one-button Mac app: iPhone → USB → offload to a destination folder
**Iteration mode:** alpha implements (coms peer on the coms-net hub) → pi-main verifies (build + screenshots + diff) → commits → acks next brief

## Status

### What's Done (chronological)

- [x] Ideation + direction: Idea 1 (Offload) with the user's redesigned flow → 7 wizard screens
- [x] offload repo (local + GitHub `MaksimZinovev/offload`); PhotosExportCore split + **engine pass 2** (`9fadf88`+`8498931`, tag `v0.1.0`, CI green)
- [x] 7-screen wizard skeleton (`062b1b8`) + bare-`swift run` window fix (`f846a47`); clarified-UX alignment (`f8f9f3d`,`c43e1b9`); grilling log Q1–Q19 (`50c17c6`)
- [x] **tldraw-mockup implementation COMPLETE** — alpha implemented 5 checkpoints + the user-caught destination hotfix; pi-main verified (build + screenshot + diff) each and committed:
  - CP1 `26d58ed` chrome+model · hotfix+CP2 `831a4c4` (`…/Offload//Offload` double-append fixed at root: base/target split + displayPath) · CP3 `543efe1` ConnectDeviceView · CP4 `73e6d66` checkbox select screen · CP5 `9a0d054` String(year) locale-format fix (+ twin found in audit) + devicePhotos single-source
  - Final E2E screenshot sweep green; pips/gates/cancel/Back verified
- [x] **"It actually exports" (IE1 `0bc3efa` + IE2 `020b911`)** — real PhotosExportCore engine behind `OFFLOAD_ENGINE=real` (default mock); `OFFLOAD_ENGINE` env gate at the single call site; output at `<picked>/Offload/YYYY/MM` (exportBase = exportTargetURL, Q19); `Sources/Offload/Info.plist` + `scripts/make-app.sh` for bundle identity. LIVE-verified by user twice: 15 assets, 481 MB, .plist sidecars, Live Photo pairs, zero failures
- [x] **IC1: real iPhone discovery (`f2abf3c`)** — `OFFLOAD_DEVICE=real`: ICDeviceBrowser + open session in DeviceSource (only ImageCaptureCore import in the target); Welcome line = real device name ("mangoPhone M3🥭") + real 2,020 photos/405 videos (= ICC probe ground truth 2,425; one batch + `deviceDidBecomeReady(withCompleteContentCatalog:)`). Demo toggle hidden in real mode; non-derivable stats hidden (never fabricated); mock mode byte-for-byte
- [x] User verified: system photo library re-designated to the 12 GB real library (was stuck on the empty natalia library — even Photos.app read as empty)

### In flight

- [x] **IC2: real iPhone download COMPLETE (`c664a5a`)** — per-item `ICCameraFile.requestDownload(options:completion:)`, sequential AsyncStream drive loop (late completions discarded, zero continuation misuse); selection: last-10 = 10 most-recent-by-captureDate (documented deviation, device path), years = captureDate-in-year, audio filtered, no-date items skipped; same event stream (screens 6–7 unchanged); 3-way call site (device → engine → mock, Q15 precedence); -9943 locked phone → clean cancel. **LIVE-VERIFIED by user: phone → `<picked>/Offload` through all 7 screens.**
- [x] README quickstart + dev commands + troubleshooting (`61a8468`) — stale-bundle lesson documented: after code changes re-run `sh scripts/make-app.sh`

- [x] **FB1: fiction→real bridge COMPLETE (see commits)** — device-mode estimate lines read the live catalog (last-10 → ≈10 real; year ticks → real per-year; ETA frozen per run, no per-event re-walk)
- [x] **PKG1: beta packaging COMPLETE (`4fe7faa`)** — `scripts/make-dmg.sh`: make-app (icon now) → ad-hoc codesign → `dist/Offload-0.1.0.dmg` (hdiutil verify + mount probe). Icon from user's `assets/` PNGs mapped by real pixel dims (filenames off-by-one-scale + byte-duplicates; no 16px source). `docs/dmg-readme.rtf` (Gatekeeper first-launch + unlocked-phone + beta note). User-VERIFIED: DMG first-launch works on the user's Mac.
- [x] **APP1: in-app device-mode toggle COMPLETE (`8310827`)** — "My iPhone (real transfer)" picker on screen 3, persisted (UserDefaults offload.deviceMode), env > pref > demo resolution (OFFLOAD_DEVICE set-not-real forces demo); verified via lsof ImageCaptureCore.loctable discriminator (demo=0, pref-real=1, env-off=0); user acceptance pending. Platform lessons: two same-named Offload processes break GUI steering (AXPress/keystroke dead — use single-instance + relaunch); ICC-loctable lsof = headless real-mode marker.
- [x] **APP1.1: build identity in the footer COMPLETE (`548c2b9`+`6c9d2f7`+`ff81a39`)** — 'Offload 0.1.1 · <commit>' every screen; stamped into the BUNDLE plist by make-app.sh (sources plist deliberately key-free: the other agent in this tree reverts Info.plist on contact — twice-caught, 16:29 + 16:31); make-dmg reads version from the bundle → filename can't drift. User-verified footer. Lessons: DMG-installed copies carry quarantine (CLI exec = windowless run, `open`/double-click fine); keystroke automation unsafe while the user is active on a second display (no more auto-typing; hand live checks to the user).
### Open design questions / side-quests

- [ ] **Fiction→real bridge**: estimate lines still show fictional `yearCounts` (18,976 etc.) — real numbers only appear at Copying; bridge = real library counts in the UI (needs an analysis step design; on-device counts now live via DeviceSource)
- [ ] Count/limit-based fetch for the MAC-engine mode ("recent N" — engine side-quest, low priority now that device mode exists)
- [ ] Style pass (per user's call; screens verified mockup-faithful)
- [ ] Family beta DMG: Makefile `.app` assembly + ad-hoc codesign + `hdiutil` → GitHub Release draft (no Apple credentials needed)
- [ ] Notarized public release (blocked on credential, below)

## Platform facts on record (verified live, 2026-10-11)

- **Real-engine launch**: needs a **bundle identity** — bare `swift run` binary → PhotoKit fetch returns authorized-but-empty, silently, no prompt (IE1 saga). `scripts/make-app.sh` assembles `.build/Offload.app`; launch its inner binary with `OFFLOAD_ENGINE=real`. A terminal already holding the Photos grant also works.
- **PhotoKit sees the system photo library only** — designation lives in Photos.app → Settings → General ("Use as System Photo Library" greyed = it already IS the designated one). The 12 GB "Photos Library.photoslibrary" was NOT designated (natalia-photos was); re-designated by user → engine + CLI + probe all read 772 real assets (2016:1, 2018:5, 2024:15, 2025:752).
- **ICC on this SDK**: `ICCameraDevice.mediaFiles` EXISTS (readonly array; header line 164) — an incremental item-keyed dict collapsed items (ptpObjectHandle values not unique at didAdd time → 2,425 became "1"); counts come from mediaFiles walks at publish boundaries only.
- **ICC + locked phone**: session open errors `-9943 "Please unlock …"` but the cached catalog still arrives; downloads will need the unlocked state (IC2 breadcrumb). No phone-side prompt appeared in the IC1 test (device already trusted from prior Image-Capture/Photos workflows).
- TCC/PhotoKit debugging recipe: instrumented probe CLI in a throwaway `.app` bundle prints bundle_id/authStatus/fetch-count — the fastest ground-truth check.

## Blockers / Risks

- [ ] Notarization credential: App Store Connect API key (preferred) or Apple ID app-specific password — user to provide; blocks the notarized release only
- [ ] Subagent model scope: built-in agent types (Explore/Plan/general-purpose) 401 unless passed `model: "glm-5.3-flash:cloud"` explicitly — standing rule
- [ ] Disk space tight (~13Gi) — `swift package clean` before big builds if ENOSPC recurs

## Decisions Made

- **Direction — Idea 1 (Offload)**; engine stays in PhotosExport (SPM `from: "0.1.0"`), Offload consumes PhotosExportCore
- **Photo source is the iPhone** (Q15) → ImageCaptureCore app-layer side; Mac-library engine stays (the user's own CLI use case)
- **Env-gate pattern** for real/placeholder: `OFFLOAD_ENGINE=real` (engine), `OFFLOAD_DEVICE=real` (device) — default = today's mock, byte-for-byte
- **Mockups are the newest source of truth** (supersede older doc/grill wording): device name fiction "iPhone 13 Pro" only in mock mode; screens 6–7 designs kept; "≈" marks estimates only (documented convention)
- **Plan screen text is verbatim** from user-experience.md (never paraphrase)
- **Placeholder discipline**: no Photos import ever; ImageCaptureCore only in DeviceSource.swift; real touches: NSOpenPanel, TMPDIR demo folder, Show in Finder, ICC browser/session (IC1+)
- **Delete-exported ships as v1.1** — wizard shows the permission UI inert (default off)
- **Minimal visuals now, style pass later** (Q3); verbatim plan + gates + Back + "Step N of 7"

## Commits This Session (offload, all pushed)

`26d58ed` CP1 · `831a4c4` hotfix+CP2 · `543efe1` CP3 · `73e6d66` CP4 · `9a0d054` CP5 · `50c17c6` Q19 · `ece700f` progress · `0bc3efa` IE1 · `020b911` IE2 · `f2abf3c` IC1 (+ docs commits)

## Sideshow (session `A6EP5Tpv46g`, localhost:8228)

- Reports: `BkrW_Z_8UDg` engine/terminal · `ZQOaEHNPF2w` six traps · `NJ7y-AXh-PY` wizard spec · `D1iRER7L8wI` decision record · `maKjCdLY3xU` release prereqs · `BfKHSunOgJE` reusable pieces · `mh2Lxz4xBh0` next steps
- Checkpoints: `glHpUDfTmgw` engine pass 2 · `yb4b70Y8Pbg` skeleton · `XX3HFwO3NBs` clarified-UX · `WQIsWGkGzUA` mockup implementation complete · `tyk3ZyDs6Ds` "It actually exports" verified

## Notes for Next Session

- **Coms plumbing (current truth)**: hub = `scripts/coms-net-server.ts` from `~/repos/pi-vs-claude-code` (restarts with sessions — port moves); the `coms_net_*` session tools abstract it (list/send/get/await — **use them, not curl**; register/heartbeat scripts and /tmp files are GONE). Alpha sessions are long-lived; turns take ~1–15 min (up to 2h on heavy turns); await-endpoint hiccups ("fetch failed") → re-poll with `coms_net_get`.
- Alpha standing rule (user-set): skills first — `~/repos/ponytail/skills/` (ponytail.md + write-swift.md) then offload `.pi/skills/` (swiftui-expert-skill + write-swift); STOP-and-ask on major issues; implement only, never commit; reply "CP/IE/ICn done: <what>" and wait.
- User feedback source of truth: `agents/user-experience.md` (untracked — exclude via `':!agents/user-experience.md'` in git add -A); grilling log `agents/wizard-skeleton-grilling.md` (Q1–Q19)
- Awaiting: alpha IC2 → user live download test (phone plugged + UNLOCKED)
- Still owed by user: notarization credential (ASC API key preferred)
- Keep posting checkpoints to sideshow `A6EP5Tpv46g`

## Roadmap 

- [ ] add prompt on iPhone to unlock device, confirm connection to app