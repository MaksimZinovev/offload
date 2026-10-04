# Session Progress Log

## Current State

**Last Updated:** 2026-10-04 18:00 (local)
**Session:** pi (PhotosExport-rooted) · review surface: sideshow `A6EP5Tpv46g` — "PhotosExport — friendly version" (localhost:8228)
**Active Feature:** Offload v1 (family beta) — one-button Mac app over PhotosExportCore

## Status

### What's Done

- [x] Ideation reviewed in sideshow: 3 app kinds — one-button Mac app / menu-bar sync agent / iOS app
- [x] Direction chosen: **Idea 1 with the redesigned 12-step flow → 7 wizard screens**
- [x] offload repo created: local + public GitHub `MaksimZinovev/offload` (README, .gitignore)
- [x] App name confirmed: **Offload**
- [x] Developer ID Application certificate: created via ego-browser (LIFELIKO PTY LTD · W628YFAY45, expires 2031-09-17), imported to login keychain; codesign smoke test passed; backups in `~/.config/offload/signing/`
- [x] PhotosExportCore refactor (in `MaksimZinovev/PhotosExport`, commit `39d9cb0`): library product split from the CLI; unsafeFlags removed → package importable via SPM; CLI behavior verified identical; CI test workflow added

### What's In Progress

- [ ] Subagent review of the refactor
  - Details: `@tintinweb/pi-subagents` configured in `offload/.pi/settings.json`, but loads only in sessions started inside `~/repos/offload`; current session is PhotosExport-rooted. Review target: PhotosExport diff `0cc5ee7..39d9cb0`.
  - Blockers: needs an offload-rooted session (or global package install)

### What's Next

1. Start a session in `~/repos/offload` (loads subagent tools) → delegate the refactor review to a subagent (consult `ponytail` + `.pi/skills/swiftui-expert-skill`, `.pi/skills/write-swift`)
2. Offload MVP: SwiftUI wizard skeleton — 7 screens per sideshow post `NJ7y-AXh-PY` (v2) — consuming PhotosExportCore via SPM
3. Family beta DMG: Makefile `.app` assembly + ad-hoc codesign + `hdiutil` → GitHub Release draft (no Apple credentials needed)
4. Notarized public release (blocked on notarization credential, below)

## Blockers / Risks

- [ ] Notarization credential: App Store Connect API key (preferred) or Apple ID app-specific password — user to provide; blocks the notarized release only, not the family beta
- [ ] XCTest absent locally (Command Line Tools only; pre-existing, verified against the untouched repo) — tests run in CI (`.github/workflows/test.yml`, first run pending)
- [ ] Subagent tools need an offload-rooted session (see In Progress)
- [ ] Apple membership card on file expired (portal alert) — renewal risk; not blocking current work

## Decisions Made

- **Direction — Idea 1 (Offload)** with the user's redesigned flow; Idea 2 (menu-bar agent) parked as v2; Idea 3 (iOS) later bet
  - Context: sideshow ideation + review; user feedback file `.local/user-experience.md` (PhotosExport, gitignored)
  - Alternatives: build the menu-bar agent or iOS app first
- **Engine stays in PhotosExport; Offload consumes PhotosExportCore via SPM**
  - Context: keeps the fork upstream-mergeable and the CLI as the power-user sibling; zero engine duplication
  - Alternatives: move/copy the engine into offload — rejected (fork-of-fork divergence, CLI homeless)
- **Keep JSON metadata + `.plist` edit recipes** (on by default) — earlier cut proposals withdrawn by user decision
- **Scope default: small batch (10 recent photos), this year** — photo counts always visible (removes the silent-year trap)
- **Wizard rules:** max 3 attention points per screen · progressive disclosure · confirm before each step · Back everywhere · global progress visible
- **Delete-exported ships as v1.1** — destructive step after the beta proves exports; leans on 30-day Recently Deleted
- **unsafeFlags dropped from the PhotosExport package** (they blocked SPM dependency use); CLI `__TEXT` Info.plist embedding removed — TCC still attributes to Terminal (documented flow unchanged)

## Files Modified This Session

PhotosExport repo (commit `39d9cb0`, pushed to `MaksimZinovev/PhotosExport` main):
- `Package.swift` — PhotosExportCore library product + executable + test targets; `.swiftLanguageMode(.v5)`
- `Sources/PhotosExportCore/{Export,Metadata,Utils,Logging,PhotosAccess,Settings}.swift` — moved from `Sources/PhotosExport` + public API surface
- `Sources/PhotosExport/Entry.swift` — renamed from `main.swift`; imports PhotosExportCore
- `Tests/PhotosExportTests/PhotosExportTests.swift` — `@testable import PhotosExportCore`
- `.github/workflows/test.yml` — new; `swift test` on macos-latest
- `.gitignore` — ignore `.local/`

offload repo:
- `README.md` — identity line
- `.gitignore` — `.DS_Store`, `.local/`
- `agents/progress.md` — this file

## Evidence of Completion

- Build: `swift build` → "Build complete!" (both targets)
- CLI smoke: `swift run PhotosExport --year notayear` → `Invalid arguments: invalidYear("notayear")` + usage + **exit 2** (identical to pre-refactor)
- XCTest failure proven pre-existing: pristine worktree of the original repo fails `swift test` identically (CLT-only machine)
- Signing smoke: test binary signed with Developer ID identity, secure timestamp, TeamIdentifier W628YFAY45
- Incident log: first `git add -A` briefly committed `.local/user-experience.md` to the public PhotosExport fork; caught within a minute, amended + force-pushed (`39d9cb0` clean); residual orphan commit SHA on GitHub until GC (unreachable without the SHA)

## Sideshow Reports (session `A6EP5Tpv46g`, localhost:8228)

- `BkrW_Z_8UDg` — The engine works — it's just wrapped in a terminal
- `ZQOaEHNPF2w` — Six traps between a normal person and their photos
- `NJ7y-AXh-PY` — Idea 1 — PhotosExport.app: the one-button Mac app (v2 = revised 7-screen wizard — the Offload spec)
- `Gp57VkO4JiI` — Idea 2 — Photos Export Sync: the set-and-forget menu bar
- `Y8slOzhZC2M` — Idea 3 — Phone to Drive: an iOS app, no Mac at all
- `D1iRER7L8wI` — Decision record — Idea 1 with your redesigned flow (v2)
- `maKjCdLY3xU` — From design to GitHub release — the concrete path (v3 = prerequisites table)
- `BfKHSunOgJE` — Reusable pieces from your GitHub stars (v2 = mac list)
- `mh2Lxz4xBh0` — Next steps — offload (checkpoint comments: cert done, refactor done)

## Notes for Next Session

- Start pi **inside `~/repos/offload`** so `@tintinweb/pi-subagents` loads; its tools are absent from PhotosExport-rooted sessions
- First task there: subagent review of the PhotosExport refactor (`git diff 0cc5ee7..39d9cb0`), ponytail + offload skills consulted
- PhotosExport has **no tags yet** — the SPM dependency needs `branch: "main"` or tag `v0.1.0` first (recommend tagging)
- Wizard spec: sideshow post `NJ7y-AXh-PY` v2; user feedback source of truth: `PhotosExport/.local/user-experience.md`
- Still owed by user: notarization credential (ASC API key preferred)
- Keep posting checkpoints to sideshow session `A6EP5Tpv46g` and arm the `sideshow wait` loop