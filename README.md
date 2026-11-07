# Meloman

**Meloman** is an offline, AppKit-based macOS karaoke-video editor. Import a music video or audio file, create word-synchronized karaoke text, adjust the words and timeline, optionally remove the lead vocal using a local model, and export an MP4.

See the [MVP roadmap](docs/ROADMAP.md) for product scope and planned milestones.

> **Status:** PR #4 adds local WhisperKit transcription with word timestamps. Vocal separation, forced lyrics alignment and MP4 export remain future milestones.

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

Select the **Meloman** scheme and run the app. Use **Импорт** (or drop media files) to load MP3/WAV/M4A/AIFF/MP4/MOV/M4V. Select a media item and use Play/Pause or the seek slider. Choose **Текст песни**, paste lines and click **Создать разметку**. The manual timing draft is an **even-duration approximation**. Use **AI текст** for real locally inferred word timestamps. Select a K1 word block on the timeline to seek and edit its text, start/end in seconds, or **Скрыть слово**. Press **Применить**, then **Сохранить** to persist everything to a portable `.meloman` folder. The karaoke overlay fills the actual glyphs from left to right as the media plays. The current editor is preview-only; video export follows in later PRs.

## Build a runnable macOS app

From the `feature/004-local-asr` branch, run:

```sh
git fetch origin
git switch --track origin/feature/004-local-asr
git pull --ff-only origin feature/004-local-asr
./scripts/build.sh
open dist/Meloman.app
```

The script installs the project's pinned Tuist release (via mise), generates the workspace, compiles a Release build, and creates:

- `dist/Meloman.app` — the complete macOS app bundle.
- `dist/Meloman.app/Contents/MacOS/Meloman` — its Mach-O executable.
- `dist/Meloman-macOS-Release-unsigned.zip` — a ZIP suitable for CI artifacts.

Optional: `./scripts/build.sh --debug` to build Debug, or `./scripts/build.sh --run` to launch after building.

**Unsigned development build:** this does not code-sign or notarize the app. For distribution to other Macs, a separate signed/notarized release pipeline will be required.


## Local AI transcription (PR #4)

WhisperKit from the Argmax open-source SDK is pinned to version **1.1.1** via Tuist's native Xcode SPM integration. On first app launch, Meloman **automatically downloads a multilingual Whisper small model** to `~/Library/Application Support/Meloman/Models`. This needs internet access and disk space once. Status appears in the footer; initialization does not block the editor. Later launches load the cached local files without a network request. After downloading, both inference and media processing run offline.

Select an imported MP3/M4A/WAV, or an MP4/MOV video, and press **AI текст**. For video, Meloman exports the audio track to a temporary M4A first (the original video is untouched). The model returns real estimated word timing; the existing K1 inspector remains available to fix recognition and timing mistakes. Existing manual lyrics are overwritten **only after explicit confirmation and successful inference**, with Undo available. All inferred lyrics stay in the portable `.meloman` project.

**Limitations:** Whisper is a speech recognition model, not specialized song alignment. Dense instrumental mixes, long-held vowels, background singers and effects may cause missing or inaccurate words. The model does not yet remove original vocals or align a supplied lyrics sheet (forced alignment is a later task). The app must not claim perfect karaoke sync.

### Accuracy with musical recordings

Plain Whisper transcription may detect only a few incorrect words on loud music.
Select **Русский** in the inspector for Russian songs to disable language auto-detection,
but this **does not guarantee** good results. If the transcript is unusually sparse,
Meloman warns before replacing any saved karaoke lyrics.

For a song with known lyrics, use **Текст песни** to paste the correct words.
Those words remain editable, but their initial timing is **only approximate**.
Accurate offline *forced alignment* of known lyrics to an isolated vocal track
is a separate upcoming milestone (candidate engines: stable-ts or a CTC aligner).
Do not treat this basic ASR as the final karaoke transcription pipeline.

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
Modules/Core/MediaPipeline/       AVFoundation-backed media metadata inspection
Modules/Core/ProjectStore/        Versioned portable .meloman package persistence
Modules/Core/KaraokeEngine/       Pure per-word timing, draft and word-fill state
Modules/Core/LocalAI/             WhisperKit adapter, model loading and local recognition
Tests/KaraokeEngineTests/         Progress/seek/hidden/per-media lyric tests
Tests/ProjectStoreTests/          Package persistence integration tests
Tests/DomainTests/                Foundation/XCTest smoke and serialization tests
Config/                           SwiftFormat and SwiftLint rules
scripts/build.sh                   Build local unsigned .app + ZIP
docs/ROADMAP.md                   MVP plan
docs/ADR/                          Architectural decisions
Project.swift / Tuist.swift       Tuist manifests
mise.toml                         Pinned Tuist version
```

Future modules (AIContracts, TimelineEngine, CompositionRenderer, ExportEngine, and feature modules) will be created in the PR that introduces their first real implementation. This avoids empty framework targets.

**Note:** PR #2 previews the currently selected media source; layered mixing, waveform, karaoke and final timeline composition follow in later PRs.\n\n**No game mode.** The editor supports manually hiding words for party videos; scoring and playing the game are handled outside Meloman.

## CI

The `CI` GitHub Actions workflow runs SwiftFormat, SwiftLint, Tuist generation, macOS unit tests, and an unsigned Release app build on pull requests and pushes to `master`. No Tuist account or cloud cache is required.
