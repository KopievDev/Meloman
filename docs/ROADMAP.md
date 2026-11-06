# Meloman — MVP Roadmap

> **Product:** офлайн-редактор караоке-видео для macOS. Основная ценность — получить из песни/клипа караоке с пословной подсветкой, исправить текст и монтаж, затем экспортировать готовый ролик.
>
> **Repository:** https://github.com/KopievDev/Meloman  
> **Platform:** macOS 15+, Apple Silicon (M1+) для первой версии  
> **Stack:** Swift 6, AppKit, Tuist, SwiftFormat, SwiftLint, Swift Concurrency, AVFoundation, Core Image / Core Text, Core ML и/или локальные inference adapters.  
> **Operating mode:** local-first / offline после однократной загрузки AI-моделей. Без аккаунта, бэкенда и облачной обработки медиа.  
> **Estimated timeline:** 14–18 недель одному опытному macOS-разработчику, включая исследование разделения вокала и стабилизацию. Не контрактный срок.

## 1. Продуктовая цель и границы

**Meloman — это не приложение для проведения игры и не видеоредактор общего назначения.** Это специализированный редактор караоке-видео: импорт, получение караоке, правка, базовый видеомонтаж, опциональное удаление вокала из аудиодорожки и экспорт.

Офлайн-игры, пропуски слов для вечеринки, выбор правильных ответов и начисление очков происходят **вне приложения**. Ведущий сам решает, как проводить игру и считать баллы. Meloman не должен реализовывать GameMode, подсчёт очков, игроков, микрофон, распознавание ответов или отдельный игровой экран.

### Сценарий A — импорт музыкального видео

1. Пользователь перетаскивает MP4/MOV с песней в Meloman.
2. Приложение извлекает аудиопоток, распознаёт слова, строит тайминги, создаёт **karaoke overlay** с прогрессивной подсветкой слова по мере пения.
3. Пользователь может исправить текст, время каждого слова, стиль и расположение текста.
4. По желанию включает чекбокс **«Убрать вокал»**. Приложение локально разделяет оригинальное аудио на `vocals` и `instrumental`, в предпросмотре и на экспорте используется инструментальная дорожка.
5. Пользователь меняет видеофон, добавляет изображения, GIF и наложения, экспортирует MP4.

### Сценарий B — импорт аудиозаписи

1. Пользователь загружает MP3/WAV/M4A/AIFF.
2. Приложение создаёт видеокомпозицию с **чёрным фоном** (16:9), автоматически создаёт караоке-текст и тайминги.
3. Фон можно заменить фотографией, GIF или видео; поверх добавить графику и другие слои.
4. По желанию включается **«Убрать вокал»**, так же как для клипа.
5. Экспортируется видео с подсветкой текста и выбранной оригинальной или инструментальной аудиодорожкой.

### Сценарий C — точечные правки и скрытые слова

Пользователь может исправлять, заменять, скрывать слова и целые строки, регулировать видимость клипов и текста на таймлайне. Это **средства видеомонтажа**, а не логика проверки ответов. Скрытие слова в видео не влечёт никакого скоринга. Удаление вокала — независимая настройка аудиодорожки.

### Must Have (MVP)

- Импорт аудио/видео с drag-and-drop, диалогом выбора, обработкой ошибок формата.
- Автоматическая локальная транскрипция пения с word timestamps, затем редактируемые караоке-фразы и слова.
- **Настоящая karaoke-анимация:** подсветка заполняет буквы слова во времени, а не просто показывает субтитры целой строкой.
- Ручная правка текста, split/merge фраз, коррекция start/end слова, правка смещения всей строки, Undo/Redo.
- Настройки шрифтов, размеров, цвета до/после подсветки, положения, обводки/тени, стилей на уровне проекта/строки/слова.
- Скрытие выбранных слов/строк, возможность заменить текст вручную.
- **Чекбокс «Убрать вокал»** для импортированного аудио или клипа; локальная AI-обработка; результат присутствует и в preview, и в экспортированном MP4.
- Звуковые stems сохраняются как производные данные; исходный аудиофайл не меняется; переключение «Убрать вокал» обратно мгновенное после готовности stems.
- Таймлайн со слоями video, background, images, GIF, karaoke, audio; простейший trim, move, resize, reorder, hide/mute, zoom/snap.
- Чёрный фон по умолчанию для аудио; возможность наложить/заменить фон видео или изображением.
- GIF с исходными задержками кадров, цикличным воспроизведением, корректным экспортом.
- Неразрушаемый проект `.meloman`, сохранение, открытие, автосохранение, восстановление путей к исходникам.
- Экспорт MP4 H.264/AAC 1080p/30fps, прогресс/отмена; синхронные видео, аудио, текст и GIF.
- Автоматическая загрузка необходимых AI-моделей по первому использованию/при первом запуске после подтверждения размера; проверки версий и хешей, подготовка/прогрев в фоне при последующих запусках.
- Работа с готовыми локальными моделями без облака; без обязательной LLM.

### Not in MVP

- GameMode / PartyMode, игроки, очки, проверка правильности слов, микрофон, запись ответа, автоматическое назначение пропусков для игры.
- Встроенный караоке-плеер для вечеринок, интерактивная работа со вторым монитором (можно добавить позже, но не блокирует MVP).
- Полноценный NLE уровня Final Cut Pro, сложные keyframes, цветокоррекция, мультикамерный монтаж.
- Облачные функции, библиотека популярных песен, импорт из YouTube / потоковых сервисов или обход DRM.
- Генеративное видео/анимации нейросетями и общая LLM.
- Идеальное удаление вокала на любой записи — модель может оставлять артефакты и части голоса.

## 2. Главные пользовательские требования: acceptance criteria

| ID | Требование | Критерий готовности |
|---|---|---|
| K-01 | Аудио → караоке | На чёрном фоне автоматически появляется пословно подсвечиваемый текст, доступный для правки |
| K-02 | Видео → караоке | Исходный видеоряд остаётся видимым под редактируемым караоке-текстом |
| K-03 | Плавная подсветка | При play/pause/seek корректна частичная подсветка **внутри** слова, включая кириллицу |
| K-04 | Редактор слов | Можно поправить ошибки ASR и времена каждого слова, разбить/объединить строки, применить Undo/Redo |
| K-05 | Медиафон | Можно поставить картинки или видео за текстом, добавить GIF на отдельном слое |
| K-06 | Remove vocals | Включённый чекбокс даёт instrumental без основного вокала в preview **и в экспортированном файле** |
| K-07 | Reversible | Выключенный чекбокс возвращает **исходную** звуковую дорожку без нового анализа |
| K-08 | Offline | После первоначальной установки моделей ASR и separation работают без подключения к интернету |
| K-09 | Project | После перезапуска текст, word timing, слои, настройки и stems восстанавливаются |
| K-10 | Export | Готовый MP4 совпадает с предпросмотром на контрольных таймкодах, не теряет звук и GIF |

## 3. Архитектура AI-пайплайна

**Не использовать универсальную LLM как базовую зависимость.** Для двух основных задач нужны специализированные локальные модели: ASR для распознавания текста и source separation для отделения вокала. Их можно скачивать, обновлять и заменять независимо.

```text
Imported MP3 / WAV / M4A / MP4 / MOV
           │
           ▼
    Media Ingest (AVFoundation)
           │
           ├─────────────── Original Media (immutable)
           │
           ▼
     Normalized Audio PCM
           │
           ├───────────────┐
           ▼               ▼
    Vocal Separator    ASR (WhisperKit)
           │               ▲
           ├── Vocals ─────┘  (optionally ASR on cleaner vocal stem)
           │
           └── Instrumental (cached)
                           │
 ASR → word timings → KaraokeDocument → LyricsEditor
                           │
         Timeline + Audio Mix Selector
                           │
                  Preview / Export
```

### 3.1. Распознавание текста

- Первый кандидат: **WhisperKit** (Swift/Core ML) с многоязычной моделью и `wordTimestamps`.
- `TranscriptionProvider` возвращает фразы, слова, start/end, confidence/provenance и язык (если доступно), но не модифицирует вручную отредактированные данные.
- Распознавать пение сложно: ASR может пропускать гласные, повторения, бэк-вокал, неверно определять границы слова. Результат — **черновик для редактирования**, а не стопроцентная гарантия.
- При необходимости переобрабатывать `vocals` stem, если это даёт более точную транскрипцию, но не ждать separation, когда не требуется.
- `WordAlignmentProvider` — расширяемый интерфейс: в MVP word timestamps + ручная коррекция; позже добавить forced alignment по исправленному тексту.
- В MVP желательно разрешить вставить готовый текст песни вручную и затем синхронизировать/исправить тайминги.

### 3.2. Удаление вокала — ключевая дополнительная функция

**UX:** в инспекторе импортированного аудио/видео и в главной панели аудиодорожки: `☐ Убрать вокал`.

- Если включено и stems ещё нет: показать `Подготовка минусовки`, прогресс, `Отменить`, ошибку и `Повторить`. Не блокировать редактор.
- Пока идёт обработка, показывать/играть оригинал с явной пометкой «Минусовка ещё не готова»; **не экспортировать оригинальный вокал молча**, если выбран removal. Экспорт ждать завершения либо предложить осознанно отключить эффект.
- После обработки — `vocals.wav` + `instrumental.wav` (или оптимизированные lossless/cache formats). Сохранить их как производные файлы, связанные с хешем исходной дорожки и версией модели.
- В режиме OFF `AudioMix` использует original; в режиме ON — instrumental. Исключить **двойной звук** (video embedded audio + separate soundtrack).
- Переключение после separation — без повторного inference и без разрушения исходника.
- В preview и MP4 должно использоваться **одно решение AudioMix** с одинаковой громкостью, временем и sample-rate conversion.
- Уровень вокала/«подсказка голосом» и ручное смешивание stems — потенциальное улучшение после MVP; для MVP хватает checkbox ON/OFF.
- Скрытие текста не должно автоматически вырезать аудио; две настройки независимы.

**Модели, которые необходимо сравнить в R&D Spike:**

1. **MDX-Net / UVR (ONNX)** — потенциально удобный и быстрый вариант для локального inference через ONNX Runtime (проверить Core ML Execution Provider на Apple Silicon).
2. **Mel-Band / BS-RoFormer** — кандидат на более качественное вокальное отделение, но особенно важно проверить лицензии конкретных весов, скорость и сложность дистрибуции на macOS.
3. **Demucs** — запасной эталон для сравнений, не обязательный backend; поддержка upstream неоднородна.
4. **Core ML Spleeter** — простой fallback / benchmark, не выбирать автоматически как лучший по качеству.

Адаптер: `VocalSeparationProvider`, с возможностью заменить реализацию без изменения UI/проектного формата. Варианты исполнения: native ONNX Runtime/Core ML; если заметно лучше качество, изолированный подписанный Python/PyTorch helper с MPS. **Не делать установку Homebrew, Python или Terminal команд обязательной для пользователя.** Если Python helper не удаётся надёжно упаковать и нотарифицировать, оставляем native backend и переносим продвинутую модель на следующий релиз.

**Оценка качества до выбора модели:** минимум 8 музыкальных фрагментов RU/EN, мужской/женский вокал, живая запись, плотная аранжировка, бэк-вокал. Слепое сравнение A/B по слышимому остаточному вокалу, артефактам/потере инструментов, времени обработки на M1/M2, RAM/disk, воспроизводимости экспорта. Выбрать модель на основе прослушивания и замеров, **не по числу параметров**. Возможность восстановления бэк-вокала не обещать в MVP.

**Лицензирование:** лицензия репозитория inference-кода **не означает** такую же лицензию на скачиваемые веса. Для каждой модели хранить идентификатор, version, URL, license, attribution, SHA-256, размер и источник. Не поставлять коммерчески сомнительные checkpoint'ы без проверки условий.

### 3.3. `ModelManager` и офлайн-работа

Состояния: `notInstalled → downloading → verifying → readyOnDisk → loading → readyInMemory`, а также `failed`, `cancelled`, `insufficientSpace`, `offline`.

- При первом запуске показать настройку локального AI, объяснить объёмы моделей, попросить подтверждение загрузки; приложение при этом можно использовать вручную.
- Сразу после подтверждения загрузить модель(и) автоматически, показать проценты, размер/место и отмену.
- При следующих запусках проверить наличие и integrity и **асинхронно** подготовить выбранные модели без блокировки AppKit окна; для тяжёлой separation-модели допускается lazy load непосредственно при задаче.
- Кеш: `~/Library/Application Support/Meloman/Models/`. Производные audio stems — в `.meloman/Derived/` проекта.
- Возможность очистить, повторно скачать, выбрать модель; безопасная дозагрузка, контроль диска, checksum, atomic rename.
- Полностью офлайн после установки моделей. Никаких сетевых обращений при анализе локальных медиа.
- Не запускать отдельную LLM или постоянный AI-демон: `ModelManager` управляет библиотекой inference или отдельным локальным helper-процессом **только когда он нужен**.

## 4. Караоке-движок: не обычные субтитры

Каждое слово: `id`, `text`, `startUs`, `endUs`, `styleOverride`, `visibility` и связь с фразой. Таймкоды хранить `Int64` microseconds, на AVFoundation boundary использовать `CMTime`.

```swift
let progress = max(0, min(1, (playhead - start) / (end - start)))
```

Рисовать **два текстовых слоя** с одним layout: базовый цвет и цвет подсветки, ограниченный маской прогресса по фактической ширине глифов. Использовать Core Text для кернинга, Unicode и кириллицы; не рассчитывать ширину как `count * glyphWidth`. Для точного ведения по слогам расширить модель `KaraokeTiming` позже, сохранив совместимость с word timing.

Слои строк: previous/current/next line, обычный и подсвеченный цвет, outline/shadow, position/safe areas. При pause, seek, reverse scrub и offline export композиция должна быть детерминированной. Одинаковое ядро для preview/render.

## 5. Модульная структура Tuist

```text
Meloman/
├── Project.swift
├── Tuist/
├── Config/
│   ├── .swiftlint.yml
│   └── .swiftformat
├── App/
│   └── MelomanApp/                 # AppKit app + dependency composition
├── Modules/
│   ├── Core/
│   │   ├── MelomanDomain/        # project, words, tracks, timecodes, effect config
│   │   ├── ProjectStore/         # .meloman package, schema migrations
│   │   ├── MediaPipeline/        # import, extraction, waveform, thumbnails
│   │   ├── AIContracts/          # Transcription/VocalSeparation/Alignment
│   │   ├── LocalAI/              # WhisperKit, separator adapters, ModelManager
│   │   ├── KaraokeEngine/        # word timing + progressive-fill state/render
│   │   ├── TimelineEngine/       # clips, tracks, trim, snapping, commands
│   │   ├── CompositionRenderer/  # common preview/export frame + audio mix
│   │   └── ExportEngine/         # video/audio encode, progress, cancellation
│   └── Features/
│       ├── ProjectBrowser/
│       ├── WorkspaceEditor/      # AppKit preview, timeline, inspector
│       ├── LyricsEditor/         # word editing, timing, visibility, styles
│       └── Settings/             # local model preferences
├── Tests/
│   ├── DomainTests/
│   ├── KaraokeEngineTests/
│   ├── TimelineEngineTests/
│   ├── ProjectStoreTests/
│   ├── AudioMixTests/
│   ├── AIContractTests/
│   └── ExportGoldenTests/
└── docs/
    ├── ROADMAP.md
    └── ADR/
```

**Dependency rule:** `App → Features → Core protocols/domain`. AI model implementations plug into a composition root. Domain layer has no AppKit, ASR SDK, FFmpeg, ONNX, Python or network dependencies. Use SPM for external packages within Tuist setup.

**Protocols / extensibility seams:** `MediaImporter`, `TranscriptionProvider`, `VocalSeparationProvider`, `WordAlignmentProvider`, `KaraokeRenderer`, `AudioMixProvider`, `TimelineEffect`, `OverlayDecoder`, `CompositionExporter`, `ModelRepository`.

**Technical priorities:** async/await and actors where justified; dedicated I/O queues for decoding; undo commands as transaction-based operations; SwiftFormat/SwiftLint in CI; deterministic test fixtures and no copyrighted music committed to repository.

## 6. Редактор AppKit и таймлайн

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Meloman  [Import] [Generate Karaoke] [Export]   ☐ Remove vocals   [status] │
├──────────────────┬─────────────────────────────────────┬──────────────────┤
│ MEDIA / ASSETS   │            VIDEO PREVIEW            │ INSPECTOR        │
│ • song.mp3       │    «Караоке с плавной подсветкой»   │ Font / Size      │
│ • clip.mov       │                                     │ Text / Timing    │
│ • bg.jpg         │                                     │ Color / Effects  │
│ • overlay.gif    │                                     │ Hide / Replace   │
├──────────────────┴─────────────────────────────────────┴──────────────────┤
│ ▶/▌▌   01:20.500        Zoom − / +    Snap    Undo / Redo                │
├─────────────────────────────────────────────────────────────────────────────┤
│ V3   GIF / Overlays         [overlay.gif]                                │
│ V2   Karaoke text      [line 1][line 2][line 3]                          │
│ V1   Background        [black / bg image / bg video]                     │
│ V0   Original video    [source video]                                    │
│ A1   Music             ~~~~~~~~~~~ source audio / instrumental ~~~~~~~~   │
└─────────────────────────────────────────────────────────────────────────────┘
```

- Timeline tracks: `SourceVideo`, `Background`, `Karaoke`, `Image/GIF Overlay`, `SourceAudio`.
- Минимальные инструменты: select, move, trim, split, hide, mute, zoom, snapping, track height, playhead, waveform, keyboard shortcuts с русской раскладкой.
- Двойной клик по тексту → inline editing; список слов с `start/end`; drag handles и nudging с клавиатуры.
- Приоритеты стиля: `ProjectStyle → LineStyle → WordOverride`.
- Чекбокс удаления вокала относится к исходному аудио в любом импортированном файле; его состояние явно видно в UI.
- GIF decode — ImageIO + корректные `frameDuration`; frame selection от playhead; preview/export parity.
- Фоны: black / solid color / image / video. Для импортированного клипа исходное видео является базовым background по умолчанию.
- Эффекты не являются отдельными генеративными AI-процессами: простые анимации/позиционирование работают в renderer.

## 7. Формат проекта `.meloman`

```text
Party Song.meloman/
├── manifest.json         # schemaVersion, canvas, fps, model provenance, asset IDs
├── timeline.json         # tracks, clips, layers, audio source selection, z-order
├── lyrics.json           # phrases, words, timings, style and hidden flags
├── Media/                # imported original media, untouched
├── Derived/              # stems, waveforms, thumbnails, analysis outputs
└── Cache/                # disposable render cache
```

- Portable package по умолчанию; сохранять исходники внутри `Media`. Optional external references можно добавить позднее.
- `AudioSourceChoice = original | instrumental`; `vocalRemovalEnabled` хранится в проекте, но не перезаписывает исходник.
- Derived-cache invalidation: original content hash + separator model ID/version + inference settings + sample rate.
- Стабильные UUID и schema migrations; atomic save and auto-recovery. Очистка derived не должна ломать проект: нужные данные пересчитываются.
- Состояния AI-анализа/исправленный текст хранить отдельно, чтобы повторная транскрипция никогда не уничтожала ручные правки без явного согласия.

## 8. Поэтапный план (14–18 недель)

### M0 — Bootstrap + domain (неделя 1)

- Tuist workspace, AppKit shell, SwiftLint/SwiftFormat, CI, SPM, logging.
- Базовые `Project`, `Track`, `Clip`, `LyricLine`, `LyricWord`, `Timecode`, `VocalRemovalConfiguration`.
- ADR по timebase, `.meloman` package и аудиомиксу.
- **Done:** Xcode project генерируется `tuist generate`, app запускается, smoke/unit tests проходят.

### M1 — Import + проект + media preview (недели 2–3)

- Drag/drop MP3/WAV/M4A/MP4/MOV; аудио метаданные, waveform, thumbnails.
- Black background для audio-only; исходный видеоряд для video; seek/play/pause.
- Создание, сохранение и повторное открытие `.meloman`.
- **Done:** импортированные аудио и видео воспроизводятся одинаково после повторного открытия проекта.

### M2 — KaraokeEngine + ручной текст (недели 4–5)

- Слова, фразы, timings, progressive text-mask renderer; стили, скрытие слов.
- Ручной ввод текста, исправление времён; early export smoke test.
- **Done:** на размеченной 3-минутной записи работает подсветка внутри слов с корректным seek и экспортом короткого тестового фрагмента.

### M3 — Локальный AI / транскрипция (недели 6–7)

- ModelManager: download/checksum/cache/async load/errors, offline mode.
- WhisperKit adapter; word timestamps; импорт результатов в редактируемую модель.
- **Done:** импортированный RU/EN трек создаёт редактируемый karaoke draft; нет обязательного сервера; offline rerun работает после загрузки модели.

### M4 — Качественное удаление вокала (недели 8–10)

- **Сначала R&D Spike:** сравнить MDX-Net/UVR, RoFormer и baseline на Apple Silicon, проверить конкретные лицензии, производительность и упаковку.
- Разработать `VocalSeparationProvider` с кэшированием `vocals` + `instrumental`.
- Чекбокс **«Убрать вокал»**: OFF original, ON instrumental; прогресс, отмена, retry; A/V sync.
- **Done:** и для MP3, и для MP4 экспорт с включённым эффектом даёт инструментальную версию; при выключении возвращается исходное аудио, без перерасчёта.

### M5 — Многослойный редактор (недели 11–13)

- AppKit timeline, drag/trim/reorder/snap/zoom, текстовый inspector, Undo/Redo.
- Фоны (black/image/video), GIF, базовые transforms, font/color/outline/shadow.
- Превью на общей композиционной модели.
- **Done:** можно поменять 5 слов и их времена, скрыть слово, заменить фон, добавить GIF, сохранить, открыть и корректно откатить правки.

### M6 — Export + beta hardening (недели 14–16; резерв до 18)

- MP4 H.264/AAC 1080p30, прогресс, отмена, disk/memory checks.
- Preview/export golden tests на контрольных кадрах и audio-mix parity; пакетирование AI backend и моделей; hardened runtime, signing, notarization, DMG.
- Offline/low-disk/corrupted media/cancel tests, QA на разных аудиофайлах.
- **Done:** DMG `0.1.0-beta` содержит полноценный offline editor, караоке, vocal removal, слои и корректный экспорт.

## 9. Приоритетный PR backlog

1. `PR #1` — Tuist/AppKit scaffold + SwiftFormat/SwiftLint + CI + domain models.
2. `PR #2` — `.meloman` project store + MP3/MP4 import + preview + waveform.
3. `PR #3` — karaoke word-fill renderer + manual lyrics & timings + tests.
4. `PR #4` — ModelManager + WhisperKit transcription + download/initialize/offline.
5. `PR #5` — vocal separation benchmarks, chosen backend, cached stems, ON/OFF toggle.
6. `PR #6` — AppKit timeline + LyricsEditor + styles + hiding + Undo/Redo.
7. `PR #7` — image/video/GIF overlays, preview/export renderer parity.
8. `PR #8` — stable MP4 export, model bundling, regression tests, beta DMG.

Номера — условный порядок **будущих** PR, не перечень уже созданных запросов.

## 10. QA / nonfunctional requirements

- Тестовый набор: минимум 8 треков (RU/EN, разные вокалы, жанры и фонограммы), включая 2 исходных видео.
- Проверять оригинал и instrumental на всех путях (`audio-only`, `video embedded audio`, `background video with own audio`), не допускать задвоения дорожек.
- Проверка ASR: word error rate на вручную размеченном небольшом датасете, корректируемость текста и таймингов; никаких обещаний абсолютной точности.
- Проверка vocal removal: оценка слепым прослушиванием, остатки вокала, потеря инструментов, длительность inference, память, размеры моделей.
- Связь preview/export: кадры на фиксированных временных метках, GIF frames, karaoke highlights, alignment звука.
- Негативные сценарии: нет интернета при повторном старте, download interrupted, insufficient disk, отмена inference/export, повреждённое видео, перемещённый проект, несовместимая модель.
- Playback не блокирует UI, inference не выполняется на main thread; большие медиа обрабатываются потоком, без загрузки полного исходника в RAM.
- Подпись, notarization, соответствующие entitlements, лицензии моделей/весов; никаких системных Python/Homebrew установок.

## 11. Риски и решения

| Риск | Решение |
|---|---|
| WhisperKit неточно распознаёт пение | Ручное редактирование слова и времени; optional source separation before ASR; future forced alignment |
| Разделение оставляет вокал или разрушает инструменты | Benchmark нескольких моделей, выбор качество/ресурсы; исходный звук всегда доступен |
| Нужны разные runtime для лучших моделей | Adapter/provider, spike native ONNX/Core ML vs packaged helper; не тянуть в Domain |
| Долгое разделение на старых Mac | Явный прогресс, cancel, cached stems, выбор лёгкой модели после Spike |
| Экспорт содержит вокал при включённом чекбоксе | Block export until separation completed or require explicit disable; единственный AudioMix selector |
| Стиль/тайминг отличается при экспорте | Общая модель времени/рендер-функции и golden tests |
| Лицензии модели и публичное использование песни | Проверять права конкретных model weights; пользователь отвечает за права на исходные записи и публикацию роликов |

## 12. Ссылки для Spike / реализации

- WhisperKit (Swift + Core ML ASR): https://github.com/argmaxinc/whisperkit
- python-audio-separator (MDX, Demucs, RoFormer backends): https://github.com/nomadkaraoke/python-audio-separator
- Meta Demucs (как reference benchmark): https://github.com/facebookresearch/demucs
- Swift Spleeter (Core ML baseline): https://github.com/jiyimeta/swift-spleeter
- Apple AVFoundation video composition: https://developer.apple.com/documentation/avfoundation/avvideocomposition
- Tuist: https://docs.tuist.dev/

## 13. Первые три действия

1. Подготовить пустой AppKit/Tuist workspace, CI со SwiftFormat/SwiftLint, модули Domain/ProjectStore/MediaPipeline.
2. Сделать MP3/MP4 → единая preview-композиция → `.meloman` проект → простейший MP4 smoke export.
3. Реализовать karaoke renderer и ручной LyricsEditor **до** интеграции ASR. Далее добавить WhisperKit и отдельным PR — качественный vocal separation toggle.

---

**Product invariant:** Meloman создаёт и монтирует караоке-видео. Игровую механику, ответы и очки контролирует ведущий за пределами Meloman.