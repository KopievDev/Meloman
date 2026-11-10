# Meloman

**Meloman** is an offline, AppKit-based macOS karaoke-video editor. Import a music video or audio file, create word-synchronized karaoke text, adjust the words and timeline, optionally remove the lead vocal using a local model, and export an MP4.

See the [MVP roadmap](docs/ROADMAP.md) for product scope and planned milestones.

> **Status:** PR #11 introduces per-track karaoke appearance editing (fonts, colors, text size, and vertical placement) shared by preview and MP4 export. Arbitrary background and GIF layers remain future milestones.

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

Select the **Meloman** scheme and run the app. Use **Импорт** (or drop media files) to load MP3/WAV/M4A/AIFF/MP4/MOV/M4V. Select a media item and use Play/Pause or the seek slider. Choose **Текст песни**, paste lines and click **Создать разметку**. The manual timing draft is an **even-duration approximation**. Use **AI текст** for real locally inferred word timestamps. Select a K1 word block on the timeline to seek and edit its text, start/end in seconds, or **Скрыть слово**. Press **Применить**, then **Сохранить** to persist everything to a portable `.meloman` folder. The karaoke overlay fills the actual glyphs from left to right as the media plays. The editor now supports MP4 export of selected media with karaoke word-fill overlays.

## Build a runnable macOS app

From the `feature/010-karaoke-style-editor` branch, run:

```sh
git fetch origin
git switch --track origin/feature/010-karaoke-style-editor
git pull --ff-only origin feature/010-karaoke-style-editor
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


## High-quality separation on Apple Silicon (PR #7)

Choose the engine under **Разделение вокала**:

- **RoFormer MLX · качество** (default): Mel-Band RoFormer using MLX on
  Apple Silicon. First install the pinned MLX runtime in a private venv:
  `./scripts/setup-mlx.sh` from the repository root. This setup requires
  Python 3.10–3.13 on an arm64 Mac; use Homebrew Python 3.12 if macOS's
  `python3` is older. No Docker, server or system-wide pip installation.
  On first use MLX downloads the model (~64 MB, plus MLX runtime dependencies)
  and thereafter reuses it offline.
- **Spleeter · быстрее**: existing native Core ML option (about 36 MB model),
  usable without Python setup.

Both options work with **Отделить вокал** and **AI текст** when
**Чистый вокал для AI** is checked. Preview **Вокал / Минус / Оригинал**
and compare results. The tracks are kept in **separate per-model caches**:
switching engines does not silently reuse an older Spleeter result.
The model selector is locked while processing.

The RoFormer integration invokes `mlx-audio-separator==0.1.20` from
`~/Library/Application Support/Meloman/Engines/MLX/bin/mlx-audio-separator`,
using the catalog model `mel-roformer-zfturbo-vocals-v1-mlx`. The installer
only creates an isolated runtime; the first model download is initiated by
the **Отделить вокал** or **AI текст** action. No media is sent to a cloud
inference service. Model files are downloaded from Hugging Face on first use.
Progress uses an activity indicator during MLX inference because this CLI
does not expose a reliable overall completion fraction. Failures preserve
the original audio, and Spleeter remains available as a fallback.

**Quality is not guaranteed:** the results depend on the song and stem quality.
The high-quality mode is an experimental opt-in runtime in this MVP; before
shipping a notarized public application, bundle or manage its runtime and
review model-weight licenses, security and offline packaging.


## Experimental BS-RoFormer option (PR #8)

The Inspector now exposes **BS-RoFormer · эксперимент** as a third vocal
separation profile. It runs the `model_bs_roformer_ep_317_sdr_12.9755.ckpt`
checkpoint supported by our pinned `mlx-audio-separator==0.1.20` runtime.
It can improve vocal clarity on some mixes but is **not guaranteed to outperform**
the current Mel-Band model, especially for individual consonants and ad-libs.

The first run may need to download a large checkpoint and convert it to MLX.
Install the optional conversion dependencies in Meloman's existing private venv:

```sh
./scripts/setup-mlx.sh --quality
```

This installs extra Python conversion tools (including PyTorch and ONNX) in
the **private** environment only. It can require considerable disk space,
download time and extra memory; it never installs into system Python. After
conversion/model caching, inference is local and offline.

- **Spleeter · быстрее** — native Core ML baseline
- **Mel-Band RoFormer · качество** — existing working lightweight MLX model
- **BS-RoFormer · эксперимент** — optional heavyweight model

All three use distinct cache namespaces. Switching engines does not silently
recycle another model's vocals. For a proper comparison, listen to the same
10–20 second verse of the song with all three models, noting instrumental
bleed and consonant preservation separately. Keep the existing Mel-Band
model as the default: it has already been tested on a real song.

The MLX package's current model support is pinned to v0.1.20. Larger
preconverted models in a forthcoming Hugging Face catalog are not yet
integrated into that released package and are intentionally not used here.
**Distribution caveat:** the BS checkpoint license must be reviewed before
shipping the trained weights in a public installer; this PR only supports
the user's local opt-in download.

## Known-lyrics synchronization (PR #9)

**Recommended for Russian rap and songs with unusual wording:** Paste the
**correct** lyrics into **Текст песни** (replace any incorrect Whisper output),
then click **Синхронизировать текст** under **Разделение вокала**. The app
keeps **every original word, spelling, punctuation, line break, and hidden-word
setting**; only the word start/end timestamps change.

Install an optional local multilingual **music-specific CTC forced aligner**
before the first use:

```sh
./scripts/setup-aligner.sh
./scripts/build.sh --run
```

This creates a private Python venv at
`~/Library/Application Support/Meloman/Engines/LyricsAligner` and installs
pinned PyTorch / Transformers dependencies. The first synchronization
downloads the [`mrfakename/w2v-bert-2.0-music-lyrics-ctc`](https://huggingface.co/mrfakename/w2v-bert-2.0-music-lyrics-ctc)
multilingual music model (about **2.5 GB** of FP32 weights; extra cache
and runtime memory required) into
`~/Library/Application Support/Meloman/Models/LyricsCTC`. A Mac with
Apple Silicon and sufficient free disk space/RAM is required. Subsequent
inference can run offline. The lyrics/audio are processed on-device, not
uploaded to a transcription server. Weights have an MIT model-card license,
subject to reviewing the original model lineage before redistribution.

The acoustic model runs on the selected original or separated vocal track
(**Чистый вокал для AI**, currently BS-RoFormer is best for the test song).
It computes 24-second time windows with two seconds of context and aligns
the **exact pasted text** using CTC Viterbi. It reports true progress during
window inference and leaves the UI responsive.

**Quality warnings:** CTC word start estimates are more dependable than word
end estimates; the latter use a conservative approximate tail. Unknown
characters and low-confidence regions may remain imperfect. Unmatched words
retain their previous timing, and low-confidence blocks appear **orange** in
the K1 timeline. If too many words have weak timing evidence, the application
asks for confirmation before applying anything. All changes remain undoable.
Repeated choruses, skipped lyrics and extra ad-libs can still make a
full-song global alignment drift; manually inspect those sections.

This is the *first* real acoustic alignment experiment, not a promise of
frame-perfect karaoke. Its performance on the supplied Russian rap track must
be verified locally because GitHub CI does **not** download the large model.

## MP4 video export (PR #10)

Select one imported media file, add or synchronize its karaoke words, then press
**Экспорт MP4** in the toolbar. Pick a destination using the native macOS
save dialog. By default, Meloman retains the original soundtrack. If you
check **Использовать минусовку**, it uses the selected separation model's
instrumental stem; a missing stem is generated locally and cached first.

- **MP4/MOV/M4V:** preserve the imported footage and mix in animated karaoke
  text, with video rotation from the original track. Final video is 30 fps
  and up to 1920 pixels on the long side (1080 on the short side).
- **MP3/M4A/WAV/AIFF:** generate a 1280×720 black-background MP4 with the
  same karaoke and soundtrack.
- Use AVFoundation/Core Animation for native video generation. The exported
  yellow fill advances **within words**, not whole-line captions.
- The renderer uses CoreText glyph offsets consistent with AppKit preview,
  including Russian text and masked words.
- Progress uses actual AVAssetExportSession reports. A staged temporary MP4
  is moved into place only once export succeeds; errors do not overwrite a
  previously exported movie.
- Export is always based on **currently selected media** and that file's
  saved in-memory karaoke word timing. It never reruns Whisper/CTC.

**MVP limitations:** this exports the main video/audio plus the K1 karaoke
track, not yet arbitrary background images, GIFs, titles, multiple stacked
videos, templates, or style animation. Current karaoke styling matches the
white/yellow preview convention. GPU rendering speed varies with input
resolution, duration and effects. Verify actual exported motion, audio,
orientation, and line timing on your Mac before merging PR #10.

## Karaoke appearance editor (PR #11)

The right-side inspector is now scrollable. Select an imported media item and use
**ОФОРМЛЕНИЕ КАРАОКЕ** to customize its karaoke captions:

- **Шрифт:** Helvetica Neue Bold, Avenir Next Demi Bold, Georgia Bold, or Menlo Bold.
- **Размер:** 24–112 points at reference width 1280 px.
- **Высота:** normalized vertical position (12–85% of video height from bottom).
- **Обычный / Подсветка:** independent sRGB colors, chosen through macOS color wells.
- **Отменить стиль** (up to 30 style changes per selected clip) / **Сбросить**.

Changes apply immediately to the preview and are picked up by **Экспорт MP4**
without modifying the original song or its word timing. Both visual renderers
resolve the same named font, proportional font size, sRGB colors, and vertical
position. Appearance is specific to each media item and stored alongside its
existing karaoke lyrics in `project.json`. Older `.meloman` projects without
style metadata still load with default white/yellow Helvetica Neue styling;
there is no schema migration or model download.

Manual verification: switch between two media items with different styles,
save/reopen, verify that style/lyrics persist, then export an MP4 and compare
font/color/position with interactive preview. Inspect long text, portrait
video and word-by-word highlight carefully. The project does not yet support
per-word styles or animated typography templates.

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
