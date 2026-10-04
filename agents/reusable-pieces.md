## Reusable pieces from your GitHub stars

[View in sideshow](http://127.0.0.1:8228/p/BfKHSunOgJE) · 2026-10-04 06:18 UTC

**The mac list changes the answer: two repos there de-risk the whole build — and none of it replaces code we already own (the engine is built).**

**Highest leverage, from your mac list**

| Repo | Why it matters for this build |
|---|---|
| **rsyncosx/RsyncUI** — SwiftUI GUI over the rsync engine | The architectural twin of PhotosExport.app: a polished GUI wrapping a battle-tested CLI engine, with estimate and progress UX to study. And it proves the pattern ships — DMGs on its releases page |
| **buresdv/Cork** — SwiftUI GUI over Homebrew | The same pattern again, in modern SwiftUI with tuist project management. A second reference for keeping a GUI-over-CLI app clean |
| **kuyawa/AppIcons** + **jaywcjlove/iconed** | Icon-set generation from an existing PNG — the packaging step becomes near-zero work |
| **milanvarady/Applite** — a native app store for non-App-Store Mac apps, backed by Homebrew Cask | Post-release distribution: a channel beyond GitHub Releases, and a reminder that a Homebrew Cask formula is its own channel |
| **jaywcjlove/devtutor** + **SFSymbolsPicker** | SwiftUI development aids while building the wizard |
| **f/textream** — small, focused, free SwiftUI utility | The taste benchmark: a single-purpose tool done cleanly |

**From your broader stars (the release pipeline):** uninstally's single-file `release.yml` — tag → build → ad-hoc DMG → GitHub Release — is the day-1 family beta tier; Thaw's configure-signing → notarize steps are the public tier (Thaw and tidiemme/monitorbar also become the Idea 2 references when the menu-bar version happens). I checked RsyncUI and Cork for release CI to crib: neither automates releases, so uninstally stays the source.

**Net effect:** architecture de-risked by two working references (RsyncUI, Cork) · icons near-zero effort (AppIcons) · release CI about half a day (adapt uninstally's file) · distribution mapped (GitHub Releases → Applite → Homebrew Cask).

**Not relevant here:** the window managers (SketchyBar, yabai, AeroSpace), flameshot, jellyfin-web, AltStore (iOS sideloading), and the web/AI projects.
