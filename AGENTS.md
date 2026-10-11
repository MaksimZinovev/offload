# AGENTS.md — Offload

Project instructions for any agent working in this repo (including coms-peer
implementers).

## Skills first — non-negotiable

Before writing or reviewing Swift/SwiftUI, consult the project skills in
`.pi/skills/` and the ponytail skills (user-set standing rule):

| Skill | Path | When |
| --- | --- | --- |
| `write-swift` | `.pi/skills/write-swift/` | any Swift code (modeling, concurrency, API design) |
| `swiftui-expert-skill` | `.pi/skills/swiftui-expert-skill/` | any SwiftUI view/layout/state work |
| `research-docs-grounding` | `.pi/skills/research-docs-grounding/` (symlink) | uncertainty about APIs/config/CI — gather evidence instead of guessing; required after 2 failed attempts; required on repeated odd failures |
| ponytail.md + write-swift.md | `~/repos/ponytail/skills/` | same triggers as above |

## Working rules

- Implementers: do NOT commit; reply per the briefing protocol and wait.
- `swift build` is the ground truth → if LSP reports stale "Cannot find
  type" ghosts on a fresh file, mark the false-positive once and move on.
- Batch edits before running `swift build` (one build per edit-batch).
- Platform facts and debugging recipes live in `agents/progress.md` — read
  them before re-deriving (e.g. ImageCaptureCore/PhotoKit/TCC behavior).
- Placeholder discipline: no Photos import ever; ImageCaptureCore confined
  to `DeviceSource.swift`; mock modes stay byte-for-byte.