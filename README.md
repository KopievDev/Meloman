# Meloman

**Meloman** is an offline, AppKit-based macOS karaoke-video editor. Import a music video or audio file, create word-synchronized karaoke text, adjust the words and timeline, optionally remove the lead vocal using a local model, and export an MP4.

See the [MVP roadmap](docs/ROADMAP.md) for product scope and planned milestones.

> **Status:** PR #5 adds native Core ML vocal/instrumental separation and a clean-vocal input option for Whisper. Forced lyrics alignment and MP4 export remain future milestones.

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

From the `feature/005-vocal-separation` branch, run:

```sh
git fetch origin
git switch --track origin/feature/005-vocal-separation
git pull --ff-only origin feature/005-vocal-separation
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

## Keyboard shortcuts in the karaoke editor

Meloman installs the native AppKit **Правка** menu and routes standard edit
commands through the focused text editor. This restores Copy, Paste and Select All
for the word field, start/end timing fields, and multiline lyrics dialog.

- `Cmd+C`, `Cmd+X`, `Cmd+V`: copy, cut and paste selection
- `Cmd+A`: select all in the focused text field
- `Cmd+Z`, `Shift+Cmd+Z`: undo and redo text editing

**Manual regression checklist:** focus the lyrics word field, paste Russian
text, use Cmd+A and replace it; paste `12.345` into both timing fields.
Next open **Текст песни** and paste several lines of lyrics including line
breaks using Cmd+V. Check menu **Правка → Вставить** as well.

**Note:** text editing Undo uses the native field editor; the karaoke
inspector's **Отменить / Повторить** buttons remain responsible for
previously applied word/timing changes in the project.

## AI vocal separation (PR #5)

Meloman now supports **Отделить вокал** in the Inspector. The first use downloads
a pinned two-stem **Spleeter Core ML model** (~36 MB) from the open-source
[swift-spleeter release 0.2.0](https://github.com/jiyimeta/swift-spleeter/releases/tag/0.2.0).
The model is cached in `~/Library/Application Support/Meloman/Models/`.
This uses macOS Core ML and `afconvert`, without Docker, Python or a server.

When **Чистый вокал для AI** is enabled (default), **AI текст** first creates
two derived WAV tracks, then transcribes only the vocal track with WhisperKit.
The original song and video remain intact; vocals and instrumental WAVs are
cached by SHA-256 of the original media plus model version in Application Support.
For comparison, uncheck the option and rerun `AI текст` on the original mix.
`Отделить вокал` also creates the tracks without transcribing; use
**Вокал**, **Минус**, **Оригинал** to audition the results. Audio-only preview
temporarily replaces the video preview for stems; it does not edit the source.

The separation progress reflects real processed chunks. Model download and WAV
preparation show activity without inventing percentages. Both stems are written
only when processing completes; partial files are not treated as valid cache.

**Important limitations:** Spleeter is a lightweight baseline, not RoFormer.
Some bleed, phase artifacts and mangled consonants may remain. Separating stems
does not magically provide correct Russian lyrics or forced alignment; compare
manually on several clips. Karaoke MP4 export is **not** implemented yet.

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
Modules/Core/LocalAI/             WhisperKit plus native Spleeter separation and local model cache
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
