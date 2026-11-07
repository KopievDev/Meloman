# Meloman

**Meloman** is an offline, AppKit-based macOS karaoke-video editor. Import a music video or audio file, create word-synchronized karaoke text, adjust the words and timeline, optionally remove the lead vocal using a local model, and export an MP4.

See the [MVP roadmap](docs/ROADMAP.md) for product scope and planned milestones.

> **Status:** PR #1 bootstrap only. Media importing, transcription, vocal separation, karaoke rendering, editing, and export are **not implemented yet**. Toolbar actions are intentionally disabled.

## Requirements

- macOS 15 or later
- Apple Silicon Mac (M1 or newer is the MVP target)
- Xcode with Swift 6 support
- [mise](https://mise.jdx.dev/) for the pinned Tuist version

## Getting started

```sh
git clone git@github.com:KopievDev/Meloman.git
cd Meloman
mise install
mise exec -- tuist generate
open Meloman.xcworkspace
```

Select the **Meloman** scheme and run the app. An empty AppKit editing workspace opens.

## Build a runnable macOS app

From the `feature/001-bootstrap` branch, run:

```sh
git fetch origin
git switch feature/001-bootstrap
git pull --ff-only origin feature/001-bootstrap
./scripts/build.sh
open dist/Meloman.app
```

The script installs the project's pinned Tuist release (via mise), generates the workspace, compiles a Release build, and creates:

- `dist/Meloman.app` — the complete macOS app bundle.
- `dist/Meloman.app/Contents/MacOS/Meloman` — its Mach-O executable.
- `dist/Meloman-macOS-Release-unsigned.zip` — a ZIP suitable for CI artifacts.

Optional: `./scripts/build.sh --debug` to build Debug, or `./scripts/build.sh --run` to launch after building.

**Unsigned development build:** this does not code-sign or notarize the app. For distribution to other Macs, a separate signed/notarized release pipeline will be required.

## Tests and quality checks

Install the CLI tools once using `brew install swiftlint swiftformat`, then run:

```sh
swiftformat --lint Project.swift Tuist.swift App Modules Tests --config Config/.swiftformat
swiftlint lint --config Config/.swiftlint.yml --strict
mise exec -- tuist generate --no-open
xcodebuild test -workspace Meloman.xcworkspace -scheme Meloman -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Layout

```text
App/MelomanApp/Sources/           Native AppKit app and editor shell
Modules/Core/MelomanDomain/       Platform-agnostic project, karaoke and timeline models
Tests/DomainTests/                Foundation/XCTest smoke and serialization tests
Config/                           SwiftFormat and SwiftLint rules\nscripts/build.sh                   Build local unsigned .app + ZIP
docs/ROADMAP.md                   MVP plan
docs/ADR/                          Architectural decisions
Project.swift / Tuist.swift       Tuist manifests
mise.toml                         Pinned Tuist version
```

Future modules (MediaPipeline, ProjectStore, AIContracts, LocalAI, KaraokeEngine, TimelineEngine, CompositionRenderer, ExportEngine, and feature modules) will be created in the PR that introduces their first real implementation. This avoids empty framework targets.

**No game mode.** The editor supports manually hiding words for party videos; scoring and playing the game are handled outside Meloman.

## CI

The `CI` GitHub Actions workflow runs SwiftFormat, SwiftLint, Tuist generation, macOS unit tests, and an unsigned Release app build on pull requests and pushes to `master`. No Tuist account or cloud cache is required.
