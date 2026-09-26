#!/usr/bin/env python3
"""
Pixel Hop 程序化 8-bit 音效与 BGM 生成器（仅 Python 标准库）。
输出到 assets/audio/sfx/*.wav 与 assets/audio/bgm/level_01.wav

用法：python3 tools/gen_sfx.py
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
BGM_DIR = ROOT / "assets" / "audio" / "bgm"

SAMPLE_RATE = 44100

# ---------------------------------------------------------------------------
# 各音效参数（sfxr 风格：改这里即可快速试听迭代）
# 字段：wave 0=square 1=triangle 2=noise, base_hz, sweep, len_s, vol, duty
# ---------------------------------------------------------------------------

SFX_PRESETS: dict[str, dict] = {
    "jump": {
        "wave": 1,
        "base_hz": 880.0,
        "slide": -420.0,
        "len_s": 0.10,
        "vol": 0.35,
        "duty": 0.5,
        "env": (0.0, 0.02, 0.08),
    },
    "land": {
        "wave": 2,
        "base_hz": 180.0,
        "slide": -80.0,
        "len_s": 0.07,
        "vol": 0.28,
        "duty": 0.5,
        "env": (0.0, 0.0, 0.07),
    },
    "coin": {
        "wave": 0,
        "base_hz": 1200.0,
        "slide": 600.0,
        "len_s": 0.14,
        "vol": 0.22,
        "duty": 0.25,
        "env": (0.0, 0.04, 0.10),
        "arp": [1.0, 1.26, 1.59],
    },
    "stomp": {
        "wave": 2,
        "base_hz": 120.0,
        "slide": -200.0,
        "len_s": 0.12,
        "vol": 0.42,
        "duty": 0.5,
        "env": (0.0, 0.01, 0.11),
    },
    "hurt": {
        "wave": 2,
        "base_hz": 320.0,
        "slide": -280.0,
        "len_s": 0.22,
        "vol": 0.38,
        "duty": 0.5,
        "env": (0.0, 0.02, 0.20),
    },
    "spring": {
        "wave": 0,
        "base_hz": 220.0,
        "slide": 880.0,
        "len_s": 0.28,
        "vol": 0.30,
        "duty": 0.35,
        "env": (0.0, 0.06, 0.22),
    },
    "drop": {
        "wave": 1,
        "base_hz": 520.0,
        "slide": -260.0,
        "len_s": 0.09,
        "vol": 0.26,
        "duty": 0.5,
        "env": (0.0, 0.01, 0.08),
    },
    "checkpoint": {
        "wave": 0,
        "base_hz": 440.0,
        "slide": 220.0,
        "len_s": 0.35,
        "vol": 0.28,
        "duty": 0.5,
        "env": (0.0, 0.08, 0.27),
        "arp": [1.0, 1.25, 1.5, 2.0],
    },
    "pause": {
        "wave": 0,
        "base_hz": 660.0,
        "slide": -120.0,
        "len_s": 0.08,
        "vol": 0.20,
        "duty": 0.5,
        "env": (0.0, 0.02, 0.06),
    },
    "clear": {
        "wave": 0,
        "base_hz": 523.0,
        "slide": 0.0,
        "len_s": 0.55,
        "vol": 0.26,
        "duty": 0.5,
        "env": (0.0, 0.15, 0.40),
        "arp": [1.0, 1.25, 1.5, 2.0, 1.5, 2.0, 2.5],
    },
    "game_over": {
        "wave": 1,
        "base_hz": 440.0,
        "slide": -330.0,
        "len_s": 0.65,
        "vol": 0.32,
        "duty": 0.5,
        "env": (0.0, 0.05, 0.60),
        "arp": [1.0, 0.84, 0.71, 0.63],
    },
}

# BGM：BPM、小节数（必须整小节循环）、各通道音量
BGM_BPM = 128
BGM_BARS = 8
BGM_MELODY_VOL = 0.11
BGM_HARMONY_VOL = 0.07
BGM_BASS_VOL = 0.09
BGM_NOISE_VOL = 0.015


def _osc_sample(phase: float, wave: int, duty: float) -> float:
    if wave == 0:
        return 1.0 if (phase % 1.0) < duty else -1.0
    if wave == 1:
        return 2.0 * abs(2.0 * (phase % 1.0) - 1.0) - 1.0
    return 0.0


def _noise_sample(state: list[int]) -> float:
    state[0] = (state[0] * 1103515245 + 12345) & 0x7FFFFFFF
    return (state[0] / 0x7FFFFFFF) * 2.0 - 1.0


def synth_sfx(preset: dict) -> list[float]:
    n = max(1, int(SAMPLE_RATE * preset["len_s"]))
    attack, sustain, decay = preset.get("env", (0.0, 0.02, preset["len_s"]))
    arp = preset.get("arp", [1.0])
    wave = preset["wave"]
    duty = preset.get("duty", 0.5)
    vol = preset["vol"]
    base = preset["base_hz"]
    slide = preset["slide"]
    noise_state = [12345]

    out: list[float] = []
    phase = 0.0
    for i in range(n):
        t = i / n
        t_sec = i / SAMPLE_RATE
        freq = base + slide * t
        if freq < 20.0:
            freq = 20.0

        arp_idx = min(int(t * len(arp) * 2), len(arp) - 1)
        freq *= arp[arp_idx]

        phase += freq / SAMPLE_RATE
        if wave == 2:
            sample = _noise_sample(noise_state)
        else:
            sample = _osc_sample(phase, wave, duty)

        env_t = t_sec
        if env_t < attack:
            amp = attack and (env_t / attack) or 1.0
        elif env_t < attack + sustain:
            amp = 1.0
        elif env_t < attack + sustain + decay:
            amp = 1.0 - (env_t - attack - sustain) / decay
        else:
            amp = 0.0

        out.append(sample * amp * vol)
    return out


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            s = max(-1.0, min(1.0, s))
            frames.extend(struct.pack("<h", int(s * 32767)))
        wf.writeframes(frames)


# 旋律：C 大调，每元素 (小节内拍偏移 0-15 十六分, 音高 MIDI, 长度十六分)
MELODY_PATTERN = [
    (0, 72, 4), (4, 74, 4), (8, 76, 4), (12, 79, 4),
    (0, 76, 4), (4, 74, 4), (8, 72, 8),
    (0, 67, 4), (4, 72, 4), (8, 74, 4), (12, 76, 4),
]

BASS_PATTERN = [
    (0, 48, 8), (8, 48, 8),
    (0, 53, 8), (8, 53, 8),
    (0, 55, 8), (8, 55, 8),
    (0, 48, 8), (8, 48, 8),
]

HARMONY_PATTERN = [
    (0, 60, 16),
    (0, 57, 16),
    (0, 55, 16),
    (0, 60, 16),
]


def _midi_to_hz(midi: int) -> float:
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def _render_note(
    buf: list[float],
    start: int,
    length: int,
    hz: float,
    vol: float,
    wave: int,
    duty: float = 0.5,
) -> None:
    phase = 0.0
    for i in range(length):
        idx = start + i
        if idx >= len(buf):
            break
        t = i / length
        amp = vol * (0.15 + 0.85 * min(1.0, t * 8)) * (1.0 - max(0.0, (t - 0.85) / 0.15))
        phase += hz / SAMPLE_RATE
        if wave == 0:
            s = 1.0 if (phase % 1.0) < duty else -1.0
        else:
            s = 2.0 * abs(2.0 * (phase % 1.0) - 1.0) - 1.0
        buf[idx] += s * amp


def synth_bgm() -> list[float]:
    beat_s = 60.0 / BGM_BPM
    sixteenth = int(SAMPLE_RATE * beat_s / 4)
    bar_len = sixteenth * 16
    total = bar_len * BGM_BARS
    buf = [0.0] * total
    noise_state = [98765]

    for bar in range(BGM_BARS):
        bar_start = bar * bar_len
        for off, midi, dur in MELODY_PATTERN:
            start = bar_start + off * sixteenth // 4
            length = dur * sixteenth // 4
            _render_note(buf, start, length, _midi_to_hz(midi), BGM_MELODY_VOL, 0, 0.25)

        for off, midi, dur in BASS_PATTERN:
            start = bar_start + off * sixteenth // 4
            length = dur * sixteenth // 4
            _render_note(buf, start, length, _midi_to_hz(midi), BGM_BASS_VOL, 0, 0.5)

        harm_idx = bar % len(HARMONY_PATTERN)
        off, midi, dur = HARMONY_PATTERN[harm_idx]
        start = bar_start + off * sixteenth // 4
        length = dur * sixteenth // 4
        _render_note(buf, start, length, _midi_to_hz(midi), BGM_HARMONY_VOL, 1, 0.5)

        for step in range(16):
            if step % 2 == 1:
                continue
            idx = bar_start + step * sixteenth // 4
            if idx < total:
                ns = _noise_sample(noise_state) * BGM_NOISE_VOL
                for j in range(sixteenth // 4):
                    if idx + j < total:
                        buf[idx + j] += ns

    peak = max(abs(s) for s in buf) or 1.0
    scale = 0.92 / peak
    return [s * scale for s in buf]


def main() -> None:
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    BGM_DIR.mkdir(parents=True, exist_ok=True)

    for name, preset in SFX_PRESETS.items():
        path = SFX_DIR / f"{name}.wav"
        write_wav(path, synth_sfx(preset))
        print(f"Wrote {path.relative_to(ROOT)}")

    bgm_path = BGM_DIR / "level_01.wav"
    write_wav(bgm_path, synth_bgm())
    print(f"Wrote {bgm_path.relative_to(ROOT)} ({BGM_BARS} bars @ {BGM_BPM} BPM, seamless loop)")


if __name__ == "__main__":
    main()
