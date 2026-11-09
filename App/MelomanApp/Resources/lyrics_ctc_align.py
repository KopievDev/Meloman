#!/usr/bin/env python3
"""Offline CTC forced alignment for known karaoke lyrics.

The reference is never rewritten or sent to cloud inference.
Model weights are downloaded once from Hugging Face into the caller's local cache.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import unicodedata
from pathlib import Path

MODEL_ID = "mrfakename/w2v-bert-2.0-music-lyrics-ctc"
SCHEMA_VERSION = 1
SAMPLE_RATE = 16_000


def write_json(path: Path, value: dict) -> None:
    pending = path.with_name(path.name + ".tmp")
    pending.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
    os.replace(pending, path)


def status(path: Path, title: str, detail: str, fraction: float | None = None) -> None:
    write_json(path, {"title": title, "detail": detail, "fraction": fraction})


def normalise(text: str) -> str:
    value = unicodedata.normalize("NFKC", text).lower()
    return "".join(char for char in value if char.isalpha() or char.isdigit() or char == "'")


def build_targets(lines: list[dict], vocabulary: dict[str, int], blank: int):
    """Returns emitted target tokens, token->word owner, IDs and unalignable words."""
    delimiter = vocabulary.get("|")
    if delimiter is None or delimiter == blank:
        raise ValueError("The CTC tokenizer has no valid '|' word delimiter")
    tokens = [delimiter]
    owners = [-1]
    all_ids = []
    unresolved = []
    seen = set()
    for line in lines:
        for word in line["words"]:
            identifier = word["id"]
            if identifier in seen:
                raise ValueError("Duplicate reference word IDs")
            seen.add(identifier)
            all_ids.append(identifier)
            characters = normalise(word["text"])
            token_ids = [vocabulary[ch] for ch in characters if ch in vocabulary and vocabulary[ch] != blank]
            if not token_ids:
                unresolved.append(identifier)
                continue
            word_index = len(all_ids) - 1
            tokens.extend(token_ids)
            owners.extend([word_index] * len(token_ids))
            tokens.append(delimiter)
            owners.append(-1)
    if len(tokens) < 3:
        raise ValueError("No reference words can be represented by the model tokenizer")
    return tokens, owners, all_ids, unresolved


def ctc_viterbi(log_probs, frame_times, tokens, owners, word_ids):
    """Vectorized per-frame CTC Viterbi; bounded memory, no torchaudio deprecated APIs."""
    import numpy as np

    token_ids = np.asarray(tokens, dtype=np.int32)
    frames = int(log_probs.shape[0])
    states = len(tokens) * 2 + 1
    if frames * states > 120_000_000:
        raise ValueError("The reference is too long for one alignment; split the song into sections")
    emission = np.zeros(states, dtype=np.int32)
    emission[1::2] = token_ids
    skip_enabled = np.zeros(states, dtype=bool)
    skip_enabled[3::2] = token_ids[1:] != token_ids[:-1]

    minus_infinity = np.float32(-1e30)
    score = np.full(states, minus_infinity, dtype=np.float32)
    score[0] = 0
    backpointers = np.zeros((frames, states), dtype=np.uint8)
    one = np.empty(states, dtype=np.float32)
    two = np.empty(states, dtype=np.float32)

    for frame in range(frames):
        one[0] = minus_infinity
        one[1:] = score[:-1]
        two[:] = minus_infinity
        two[3::2] = np.where(skip_enabled[3::2], score[1:-2:2], minus_infinity)
        take_one = one > score
        best = np.where(take_one, one, score)
        take_two = two > best
        best = np.where(take_two, two, best)
        backpointers[frame] = np.where(take_two, 2, np.where(take_one, 1, 0))
        score = best + log_probs[frame, emission]

    state = states - 1 if score[-1] > score[-2] else states - 2
    char_confidence = np.full(len(tokens), minus_infinity, dtype=np.float32)
    char_time = np.full(len(tokens), -1.0, dtype=np.float64)
    for frame in range(frames - 1, -1, -1):
        if state % 2:
            index = (state - 1) // 2
            value = log_probs[frame, token_ids[index]]
            if value > char_confidence[index]:
                char_confidence[index] = value
                char_time[index] = float(frame_times[frame])
        state -= int(backpointers[frame, state])

    grouped = [[] for _ in word_ids]
    confidences = [[] for _ in word_ids]
    for index, owner in enumerate(owners):
        if owner >= 0 and char_time[index] >= 0:
            grouped[owner].append(char_time[index])
            confidences[owner].append(float(np.exp(max(-40, char_confidence[index]))))

    records = []
    unresolved = []
    for word_id, peaks, probabilities in zip(word_ids, grouped, confidences):
        if not peaks:
            unresolved.append(word_id)
            continue
        start = max(0.0, min(peaks))
        end = max(peaks) + 0.12
        records.append({
            "id": word_id,
            "startSeconds": start,
            "endSeconds": end,
            "confidence": float(sum(probabilities) / len(probabilities)),
        })

    for first, second in zip(records, records[1:]):
        if second["startSeconds"] > first["startSeconds"]:
            first["endSeconds"] = min(
                first["endSeconds"],
                second["startSeconds"],
            )
        first["endSeconds"] = max(first["startSeconds"] + 0.04, first["endSeconds"])

    return records, unresolved


def compute_emissions(audio, processor, model, device: str, progress: Path):
    import numpy as np
    import torch

    core_length = 24 * SAMPLE_RATE
    flank = 2 * SAMPLE_RATE
    total = len(audio)
    chunks = []
    times = []
    for core_start in range(0, total, core_length):
        core_end = min(total, core_start + core_length)
        window_start = max(0, core_start - flank)
        window_end = min(total, core_end + flank)
        signal = audio[window_start:window_end]
        inputs = processor(signal, sampling_rate=SAMPLE_RATE, return_tensors="pt")
        inputs = {key: value.to(device) for key, value in inputs.items()}
        with torch.inference_mode():
            prediction = model(**inputs).logits[0]
            probabilities = torch.log_softmax(prediction.float(), dim=-1).cpu().numpy()
        count = probabilities.shape[0]
        timestamps = (np.arange(count) + 0.5) * (
            (window_end - window_start) / SAMPLE_RATE / count
        ) + window_start / SAMPLE_RATE
        selected = (timestamps >= core_start / SAMPLE_RATE) & (timestamps < core_end / SAMPLE_RATE)
        chunks.append(probabilities[selected].astype(np.float32))
        times.append(timestamps[selected])
        status(
            progress,
            "Акустическое выравнивание",
            f"Проанализировано {core_end / SAMPLE_RATE:.1f} из {total / SAMPLE_RATE:.1f} с",
            core_end / total,
        )
    return np.concatenate(chunks), np.concatenate(times)


def align(args) -> None:
    import numpy as np
    import soundfile as sf
    import torch
    from transformers import Wav2Vec2BertForCTC, Wav2Vec2BertProcessor

    source = json.loads(Path(args.reference).read_text(encoding="utf-8"))
    if source.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError("Unsupported reference schema")
    lines = source.get("lines", [])
    if not lines or not any(line.get("words") for line in lines):
        raise ValueError("No reference lyrics supplied")

    progress = Path(args.progress)
    cache = Path(args.cache)
    cache.mkdir(parents=True, exist_ok=True)

    waveform, sample_rate = sf.read(args.audio, dtype="float32", always_2d=True)
    if sample_rate != SAMPLE_RATE:
        raise ValueError("Expected 16 kHz PCM WAV from Meloman")
    audio = waveform.mean(axis=1)
    if len(audio) < SAMPLE_RATE:
        raise ValueError("Audio must be at least one second long")

    status(progress, "Акустическая модель", "Проверка или загрузка весов модели (~2,5 ГБ)")
    processor = Wav2Vec2BertProcessor.from_pretrained(MODEL_ID, cache_dir=str(cache))
    model = Wav2Vec2BertForCTC.from_pretrained(MODEL_ID, cache_dir=str(cache)).eval()
    vocabulary = processor.tokenizer.get_vocab()
    blank = processor.tokenizer.pad_token_id
    if blank is None:
        raise ValueError("Model tokenizer has no CTC blank token")

    tokens, owners, ids, missing = build_targets(lines, vocabulary, blank)
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    model = model.to(device)
    status(progress, "Подготовка CTC", f"Акустический движок: {device.upper()}")
    log_probs, frame_times = compute_emissions(audio, processor, model, device, progress)
    del model
    status(progress, "Синхронизация текста", "CTC Viterbi сопоставляет исходные слова с музыкой")

    aligned, invalid = ctc_viterbi(log_probs, frame_times, tokens, owners, ids)
    duration = len(audio) / SAMPLE_RATE
    for item in aligned:
        item["startSeconds"] = min(item["startSeconds"], max(0.0, duration - 0.05))
        item["endSeconds"] = max(
            item["startSeconds"] + 0.04,
            min(item["endSeconds"], duration),
        )

    unresolved = sorted(set(missing + invalid))
    write_json(Path(args.output), {
        "schemaVersion": SCHEMA_VERSION,
        "aligned": aligned,
        "unresolved": unresolved,
    })
    status(progress, "Синхронизация завершена", f"Тайминги найдены для {len(aligned)} слов", 1.0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True)
    parser.add_argument("--reference", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--progress", required=True)
    parser.add_argument("--cache", required=True)
    args = parser.parse_args()
    try:
        align(args)
    except Exception as exc:
        status(Path(args.progress), "Ошибка синхронизации", str(exc))
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
