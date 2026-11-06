# ADR 0001 — Tuist bootstrap, domain boundaries and timeline timebase

**Status:** Accepted for initial scaffolding  
**Date:** 2026-11-07

## Decision

1. Build Meloman as a **native AppKit** macOS 15+ app written in Swift 6.
2. Use a single Tuist-generated Xcode project with **separate Xcode targets** for the app, the pure Foundation domain and unit tests. Add real modules as features arrive.
3. Keep `MelomanDomain` free of AppKit, AVFoundation, AI SDKs, networking, or third-party packages.
4. Represent word/clip positions as **nonnegative Int64 microseconds** in `Timecode`. Use Core Media `CMTime` only at AVFoundation adapters. This minimizes floating-point rounding drift across edits, preview and export.
5. Preserve originals. Future `.meloman` packages will refer to original media separately from cached derivative stems; `VocalRemovalConfiguration` selects whether instrumental audio is used, but does not mutate imported media.
6. No game logic, player scores, answer checking or mic capture will live in the app.

## Consequences

- Domain encoding is deterministic and unit-testable without media or inference frameworks.
- More UI and AI modules can depend inward on domain contracts without reversing dependencies.
- A change in the vocal-removal neural network must not invalidate project structure.
- Time validity is enforced when creating/decoding `Timecode`; subsequent editable clip ranges will require additional domain validation in a dedicated module.

## Deferred

- Persistence format/versioning of `.meloman` bundles.
- Definitive source-separation backend and model license choice.
- Audio mix/preview/export synchronization details, to be decided in their own ADRs.
