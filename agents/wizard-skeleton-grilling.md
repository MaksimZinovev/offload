# Grilling — Offload 7-screen wizard skeleton (placeholders)

**Context:** Offload is a one-button Mac app that offloads an Apple Photos library to a drive. The engine (`PhotosExportCore`) lives in the PhotosExport repo and is consumed via SPM — v0.1.0 is tagged and CI-green (`exportAssets(_:logger:onEvent:) -> ExportSummary`, `ExportEvent` progress enum, `YearSelection`). This grilling session (2026-10-04) settled the design for the next iteration: a 7-screen SwiftUI wizard skeleton in the offload repo, showing the full UI and user flow E2E with **placeholder operations** (no real Photos access, no real copy, no real delete). Two system touches only: a real folder picker (NSOpenPanel) and a real temp folder for "Show in Finder". Execution: main session designs the state machine → `worker` subagent implements → `reviewer` subagent verifies → build → user clicks through E2E via `swift run`.

## Q1 — Where does the placeholder live?
A: At the event level — the wizard consumes real PhotosExportCore types (`ExportEvent`, `ExportRequest`, `ExportSummary`) and calls a `MockEngine` whose `exportAssets` signature mirrors the real one. Swap to real engine later = one call-site change, no rewrite.

## Q2 — What are the 7 screens?
A: 1 Intro/Analysis · 2 Confirm (plan) · 3 USB check · 4 Destination · 5 Scope · 6 Progress · 7 Summary. (Confirmed against the user's own flow notes.)

## Q3 — Visual fidelity?
A: Minimal now (text + basic SwiftUI controls, native window). Style pass comes later; flow/behavior is what this iteration verifies.

## Q4 — Wire SPM to PhotosExportCore v0.1.0 now?
A: Yes. Real types from day one; only the event source is fake. `from: "0.1.0"`.

## Q5 — What does the Confirm screen (2) confirm?
A: It's an informed-consent plan screen at position 2: "I'll check your library → you pick a drive → we copy → nothing is deleted." No parameters confirmation there.

## Q6 — Scope screen model?
A: Preset buttons with counts underneath — [10 recent] [This year] [All years], each showing "N photos · est time". One tap to choose; lowest cognitive load.

## Q7 — Mock pacing & Show in Finder?
A: Realistic pacing (~200-400ms between events; demo run completes in ~30-60s by accelerating the index toward the displayed total). Show in Finder opens a real temp folder the mock pre-creates.

## Q8 — Analysis on the Intro screen?
A: Simulated scan: ~2s spinner ("Looking at your library…") then fictional numbers (photos / size / estimated time). The real version needs the same state.

## Q9 — How to pass the USB screen in testing?
A: "No drive detected…" state + an explicit **(demo: simulate drive)** button — makes the placeholder visible and exercises the detection state.

## Q10 — Delete-exported UI on the Summary?
A: Interactive demo: toggle-section default off + a Delete button that does nothing destructive (flows to next/quit). Real delete ships v1.1.

## Q11 — The "+ custom range" row on Scope?
A: Visible but disabled, marked "(later)". The picker ships when real counting lands (keeps skeleton lean).

## Q12 — Back on the Progress screen?
A: No Back during a copy — a **Cancel** button (confirm-first) that aborts the mock run and returns to Scope. Matches the real engine's `Task.checkCancellation()` semantics.

## Q13 — Where does "Export more" land after the Summary?
A: Screen 1 — a fresh run with clean state (re-scan, nothing kept). Simplest mental model.

## Q14 — Confirmed and built?
A: Confirmed. Chrome: single non-resizable window, "Step N of 7" indicator top, Back/Next footer, confirm-before-step gates. Worker implements (swiftui-expert-skill + write-swift preloaded), reviewer verifies against this spec, then `swift build` / `swift run`.

## Q15 — What is the USB device and the photo source? (post-E2E feedback)
A: The iPhone. Photos live on the phone; the user connects the iPhone via USB; Offload copies phone photos to the destination. Roadmap consequence: PhotosExportCore reads the Mac's Photos library (PHAsset) — direct iPhone access needs a different API (ImageCaptureCore); queued as an engine side-quest, not blocking the skeleton.

## Q16 — Plan screen step list?
A: Name all 5 steps, including "You connect your iPhone via USB": look → connect iPhone → pick destination → copy (nothing deleted) → review summary.

## Q17 — USB screen framing?
A: "Connect your iPhone with a USB cable." Demo state: "iPhone connected: Dad's iPhone (demo)". Summary reframed to "On iPhone: N photos — unchanged".
## Q18 — Clarified user-experience.md adjustments (post-E2E)
A: The clarified doc is authoritative. Screen 2 shows the user's verbatim plan text (connect iPhone → select photos → destination → copy → delete-confirm → nothing deleted). Scope (screen 5) supersedes Q6: [The last 10 photos] preselected default + [This year] + year chips 2026-2023 multi-select + "Number of photos" chips (10/50/100/All), matched count always visible. The iPhone-as-source decision (Q15) is confirmed as the product model.
