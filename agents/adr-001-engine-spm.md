# ADR-001: Engine stays in PhotosExport; Offload consumes PhotosExportCore via SPM

> **Question (verbatim, 2026-10-04):**
> explain "Engine stays in PhotosExport; Offload consumes PhotosExportCore via SPM". How the offload  app will work if the engin is located in different repo ?

**Status:** Accepted (2026-10-04)
**Related:** sideshow session `A6EP5Tpv46g` posts `D1iRER7L8wI` (decision record), `maKjCdLY3xU` (release path)

## The one-sentence version

The engine's **source code** lives in the PhotosExport repo, but when Offload is **compiled**, the engine's compiled code gets **baked into the Offload binary**. The finished `Offload.app` is a single, self-contained file — end users never see or need the PhotosExport repo.

## How it happens — Swift Package Manager

SPM is Swift's built-in dependency mechanism (npm-like, but for Swift). Offload's `Package.swift` will declare:

```swift
dependencies: [
    // "pull the engine from my other repo on GitHub"
    .package(url: "https://github.com/MaksimZinovev/PhotosExport", branch: "main")
        // (later: from: "0.1.0" — once PhotosExport gets a version tag)
],
targets: [
    .executableTarget(
        name: "Offload",
        dependencies: [.product(name: "PhotosExportCore", package: "PhotosExport")]
    )
]
```

Then the build flow:

```
BUILD TIME (your Mac or CI — happens once, per release):

  github.com/MaksimZinovev/PhotosExport     your offload repo
        │  (SPM downloads it)                    │
        ▼                                        ▼
  PhotosExportCore ──compiled────▶ linked with Offload SwiftUI code
                                                 │
                                                 ▼
                                        Offload.app  ← ONE file
                                                 │
RUNTIME (your dad's Mac):                        ▼
  Offload.app opens → engine runs INSIDE it. No GitHub, no internet,
  no CLI, no other downloads. The .app is complete on its own.
```

1. You run `swift build` (or CI does) in `offload/`
2. SPM reads `Package.swift`, fetches your PhotosExport repo, compiles its `PhotosExportCore` library
3. The linker **copies the engine's machine code into the Offload binary**
4. You ship that binary — DMG, notarized, done. The GitHub dependency existed only at compile time.

This is the same pattern as any app using any GitHub library — nothing exotic. It's also exactly why we did the refactor first: SPM can't import a repo that's a bare `main.swift` CLI with `unsafeFlags`; it needed a proper library product (`PhotosExportCore`).

## Why not just copy the engine into offload?

Copying would create a **second, diverging copy of the engine** — a fork of your fork. Then every bugfix would need to be made twice, and your repo stops being comparable to upstream `rcarmo/PhotosExport`. With the SPM link:

- **One engine, two faces**: the `PhotosExport` CLI (power users) and Offload (family) import the *same* core — fix a bug once, both get it.
- Your fork stays clean and upstream-mergeable.
- Builds are reproducible once we tag versions (`v0.1.0` → Offload pins to it).

## Why compiled-in beats shelling out to the CLI

The alternative would be Offload running the `PhotosExport` CLI as a subprocess and parsing its text output — that's the RsyncUI pattern (GUI over a CLI). We rejected it in review because a subprocess gives no live progress reporting and no way to ever do delete-exported safely. Compiled-in, Offload calls the engine directly: `exportNextBatch()` with progress callbacks, and later `deleteExported()` with proper confirmations.

## Consequences

- Offload's `Package.swift` needs the SPM dependency wired (next: MVP skeleton).
- PhotosExport needs a **version tag** (`v0.1.0`) so offload can pin a stable release instead of tracking `main` — a one-liner when we wire the dependency.
- Engine changes (new features, bugfixes) are made in the PhotosExport repo and flow into Offload on the next build; Offload repo only contains app code.