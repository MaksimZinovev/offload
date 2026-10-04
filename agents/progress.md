# Session Progress Log

## Current State

**Last Updated:** 2026-10-04 evening (local)
**Session:** pi (offload-rooted, `~/repos/offload`) · review surface: sideshow `A6EP5Tpv46g` — "PhotosExport — friendly version" (localhost:8228)
**Active Feature:** Offload v1 (family beta) — one-button Mac app: iPhone → USB → offload to a destination folder

## Status

### What's Done

- [x] Ideation + direction: Idea 1 (Offload) with the user's redesigned flow → 7 wizard screens
- [x] offload repo created (local + public GitHub `MaksimZinovev/offload`)
- [x] Developer ID Application certificate: LIFELIKO PTY LTD · W628YFAY45 (expires 2031-09-17), in login keychain; backups in `~/.config/offload/signing/`
- [x] PhotosExportCore library split (`39d9cb0`) + subagent review (verdict FIX-THEN-SHIP) → **engine pass 2** (`9fadf88` + `8498931`):
  - `exportAssets(_:logger:onEvent:) -> ExportSummary` + `ExportEvent` events; export loop lives in Core, CLI `Entry.swift` is a thin adapter; CLI behavior verified identical
  - `YearSelection` enum kills the force-unwrap; library de-terminaled (no stderr writers in Core); ponytail −3 lines
  - **CI green** on `8498931` — the two red `39d9cb0` runs were a pre-existing ill-typed test assertion (masked as a Swift compiler bug), fixed
  - **Tag `v0.1.0`** on `8498931` — SPM pin for Offload
- [x] **7-screen wizard skeleton shipped** (offload `062b1b8`, ~630 lines, placeholders everywhere):
  - Subagent-built ("wizard-skeleton" worker) + subagent-reviewed (reviewer + ponytail): progress screen unreachability BLOCKER + 0-based index fidelity fixed; ponytail net −14
  - SPM → PhotosExportCore `from: "0.1.0"`; mock at the event level (`MockEngine.exportAssets`, same signature + `limit:`) — real-engine swap = one call site
  - Placeholder discipline verified: no Photos import; only real touches = NSOpenPanel + TMPDIR demo folder + Show in Finder
- [x] Bare `swift run` fix (`f846a47`): no-bundle executables launch background-only → window invisible; `.setActivationPolicy(.regular)` in `App.init` — verified rendering
- [x] **Aligned to clarified user-experience.md** (`f8f9f3d` + `c43e1b9`):
  - Plan screen (2): user's verbatim plan text (connect iPhone → select photos → destination → copy → delete-confirm → nothing deleted)
  - USB screen (3): "Connect your iPhone with a USB cable" (demo: "Dad's iPhone")
  - Scope screen (5): **[The last 10 photos] preselected** + [This year] + year chips 2026-2023 multi-select + "Number of photos" 10/50/100/All chips; matched count + estimate always visible
  - Summary: "On iPhone: 62,539 photos — unchanged"

### What's In Progress

- [ ] **User's second E2E click-through of the adjusted flow** — verdict decides: style pass vs real-ops engine work next

### Open design questions / engine side-quests (when real ops land)

- [ ] **iPhone-as-source (Q15 reframe)**: the photo source is the iPhone, not the Mac Photos library → `PhotosExportCore` reads the Mac library only (PHAsset); direct iPhone access needs **ImageCaptureCore** (ICCameraDevice) in the engine, or an import-first bridge — ADR-level decision pending
- [ ] Analysis timing with iPhone-as-source: screen 1 (scan/counts) precedes the connect step, but an unconnected phone can't be counted — real ops likely move analysis after connect (needs the user's word)
- [ ] Count/limit-based fetch for "recent N"; photo-count query API; typed metadata at the GUI boundary (replaces `[String: Any]`)

### What's Next

1. Style pass (per E2E verdict) — the standing "minimal now, style later" decision
2. Real-ops engine work (side-quests above), or straight to packaging per user's call
3. Family beta DMG: Makefile `.app` assembly + ad-hoc codesign + `hdiutil` → GitHub Release draft (no Apple credentials needed)
4. Notarized public release (blocked on notarization credential, below)

## Blockers / Risks

- [ ] Notarization credential: App Store Connect API key (preferred) or Apple ID app-specific password — user to provide; blocks the notarized release only
- [ ] Apple membership card on file expired (portal alert) — renewal risk; not blocking current work
- [ ] Subagent model scope: built-in agent types (Explore/Plan/general-purpose) 401 unless passed `model: "glm-5.3-flash:cloud"` explicitly; custom types (worker/reviewer/researcher/…) are pinned and work — standing rule when spawning subagents

## Decisions Made

- **Direction — Idea 1 (Offload)** with the user's redesigned flow; menu-bar agent parked as v2; iOS later
- **Engine stays in PhotosExport; Offload consumes PhotosExportCore via SPM** (`from: "0.1.0"`) — keeps the fork upstream-mergeable; zero engine duplication
- **Photo source is the iPhone** (grilling Q15): user connects iPhone via USB; app copies phone photos to the destination — consequence: engine needs ImageCaptureCore/import-bridge for real ops
- **Plan screen text is verbatim from user-experience.md** (user wrote the 6-line plan; do not paraphrase)
- **Scope UI (Q6 superseded by clarified doc)**: "The last 10 photos" preselected default, plus year chips + photos-to-export count control; counts always visible
- **Placeholders at the event level** (grilling Q1): mock mirrors the real `exportAssets` signature; swap = one call site — no engine protocol abstraction
- **Minimal visuals now, style pass later** (grilling Q3)
- **Wizard rules:** max 3 attention points per screen · progressive disclosure · confirm before each step · Back everywhere (except during copy: Cancel-with-confirm) · global "Step N of 7" progress
- **Delete-exported ships as v1.1** — skeleton shows the permission UI as an inert demo (default off)
- **Keep JSON metadata + `.plist` edit recipes** (on by default)

## Commits This Session

PhotosExport (pushed):
- `9fadf88` — GUI-ready engine API: exportAssets/ExportEvent, YearSelection, de-terminaled Core, thin Entry adapter, Package.swift ponytail
- `8498931` — CI crater fix (ill-typed test assertion) → **CI green**
- `v0.1.0` — tag on `8498931`
- (prior session: `39d9cb0` library split)

offload (pushed):
- `443a44b` — docs: review outcome, ADR-001 API note, `.pi/` gitignored, reusable-pieces exported
- `062b1b8` — 7-screen wizard skeleton (subagent pair: worker → reviewer+ponytail)
- `9be1e6f` — chore: `.build/` gitignored, progress log
- `f846a47` — fix: background-only window on bare `swift run`
- `f8f9f3d` — feat: clarified UX (iPhone source, plan verbatim, chips scope)
- `c43e1b9` — docs: grilling Q18

## Evidence of Completion

- Engine: `swift build` clean both targets; CLI arg smoke identical (`--year notayear` / `--end-year` alone / inverted range → exit 2); CI green in 45s on macOS runner (37 tests)
- Skeleton: `swift build` clean; offload binary launches; window renders (screenshot-verified Step 1: step indicator + fictional analysis numbers + Continue)
- Subagent infra smoke-tested (echo round-trips through worker/reviewer/general-purpose types)

## Sideshow Reports (session `A6EP5Tpv46g`, localhost:8228)

- `BkrW_Z_8UDg` — The engine works — it's just wrapped in a terminal
- `ZQOaEHNPF2w` — Six traps between a normal person and their photos
- `NJ7y-AXh-PY` — Idea 1 (v2 = the 7-screen wizard spec)
- `D1iRER7L8wI` — Decision record — Idea 1 with your redesigned flow
- `maKjCdLY3xU` — From design to GitHub release (v3 = prerequisites table)
- `BfKHSunOgJE` — Reusable pieces from your GitHub stars
- `mh2Lxz4xBh0` — Next steps — offload
- Checkpoints this session: `glHpUDfTmgw` (engine pass 2 done, v0.1.0) · `yb4b70Y8Pbg` (skeleton shipped) · `XX3HFwO3NBs` (clarified-UX alignment)

## Notes for Next Session

- Start pi **inside `~/repos/offload`** (subagent tools load there)
- **Subagent standing rule (user-set):** consult ponytail skills (`~/repos/ponytail/skills/`) + offload `.pi/skills/` — workers: write-swift + swiftui-expert-skill; reviewers: those + ponytail-review; built-in types need `model: "glm-5.3-flash:cloud"`
- User feedback source of truth: `offload/agents/user-experience.md` (deliberately untracked); grilling decision log: `agents/wizard-skeleton-grilling.md` (Q1-Q18)
- Groomed Qs awaiting user: analysis-timing with iPhone source; style pass scope
- Still owed by user: notarization credential (ASC API key preferred)
- Keep posting checkpoints to sideshow `A6EP5Tpv46g`; disk space is tight (~13Gi) — `swift package clean` before big builds if ENOSPC recurs