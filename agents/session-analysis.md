
 Alpha session forensics — where friction and tokens actually went

 Session shape: 279 assistant turns, 148 tool calls, ~523K tokens total (385K in / 138K out), 1 compaction at
 222K. No prompt-cache accounting on this provider (cacheRead: 0 everywhere) — every turn re-bills its input
 whole, so context size pays linearly. Ranked findings:

 ### 1. Off-topic work polluted the worker session (~50K tokens + compaction pressure)

 The session's biggest single turn (50.8K) was ghostty/Muxy font debugging — powerline glyphs, NerdFont
 nameIDs, binary strings greps. That's the user's side-quest routed through alpha-in-offload. It burned a
 third of the budget that led to compaction.

 Fix: side tasks → throwaway session; alpha stays single-purpose per repo.

 ### 2. API re-discovery churn: 22 ImageCaptureCore header greps + 5 self-written probes + Apple-doc fetches

 Every grep re-resolves SDK=$(xcrun --show-sdk-path) and slices .h files piecemeal — and alpha independently
 re-derived the same facts I'd already verified (mediaFiles array, catalog signal, download API). Duplicate
 cross-agent discovery, twice.

 Fix (highest leverage): a distilled .pi/references/imagecapturecore.md in the repo — one-time API map from
 today's verified facts (mediaFiles, delegate required set, modern requestDownload, -9943 semantics, mask
 quirks). Briefs cite header line numbers as ground truth instead of delegating "your header check decides".
 Saves ~30–50K tokens per ICC iteration.

 ### 3. Build obsession: 18 swift builds, each paying an extra tee-log indirection

 Builds interleaved after single edits (edit→build→edit→build at 12:30–12:32), and rtk tees output to a /tmp
 log that alpha must read back — once per build, twice when the first read truncates.

 Fix: batch edits → one build; drop the tee/log indirection (read tail inline).

 ### 4. LSP ghost-hunting

 Stale single-file-index "Cannot find type" artifacts on fresh files → full lens_diagnostics sweeps, 4–5
 formal false-positive marks, extra build+LSP probes to "prove" clean.

 Fix: protocol rule for alpha — swift build is truth; if a fresh file's LSP ghost survives a green build,
 mark once and move on; never sweep mid-iteration.

 ### 5. Briefs that don't embed verified API facts

 IE1 went surgical because the brief carried facts; IC1 delegated API choice and paid for it. My process fix:
 verify header/API facts before briefing, always.

 Small win: multi-hunk edits in one call instead of three single-line cycles.

 Net estimate: items 1–4 ≈ 150–200K of the session's tokens were avoidable. The skills are working — this is
 infrastructure friction, not skill friction. Ready to do the Fiction→real bridge brief (with a built
 references-file task first) whenever you say.