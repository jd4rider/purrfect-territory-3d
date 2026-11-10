#!/usr/bin/env python3
"""Synthesise Purrfect Territory 3D's audio.

    python3 Tools/audio.py

Everything is generated from maths, so the repository carries no third-party
audio. Writes mono 16-bit WAVs into Assets/Audio/{SFX,Music}.
"""
from __future__ import annotations

import pathlib

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / "Assets" / "Audio" / "SFX"
MUSIC = ROOT / "Assets" / "Audio" / "Music"
SR = 22050


def write(path: pathlib.Path, samples: np.ndarray) -> None:
    import wave

    path.parent.mkdir(parents=True, exist_ok=True)
    peak = float(np.max(np.abs(samples))) or 1.0
    data = np.clip(samples / peak * 0.86, -1.0, 1.0)
    pcm = (data * 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())
    print("wrote", path.relative_to(ROOT), round(len(samples) / SR, 2), "s")


def t(duration: float) -> np.ndarray:
    return np.linspace(0.0, duration, int(duration * SR), endpoint=False)


def env(duration: float, attack: float = 0.01, release: float = 0.2, curve: float = 2.0) -> np.ndarray:
    time = t(duration)
    value = np.ones_like(time)
    a = max(1, int(attack * SR))
    value[:a] = np.linspace(0.0, 1.0, a)
    r = max(1, int(release * SR))
    value[-r:] *= np.linspace(1.0, 0.0, r) ** curve
    return value


def tone(freq: float, duration: float, amp: float = 1.0, shape: str = "sine") -> np.ndarray:
    time = t(duration)
    phase = 2.0 * np.pi * freq * time
    if shape == "triangle":
        signal = 2.0 * np.abs(2.0 * ((time * freq) % 1.0) - 1.0) - 1.0
    elif shape == "soft":
        signal = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.14 * np.sin(3 * phase)
    else:
        signal = np.sin(phase)
    return signal * amp


def bell(freq: float, duration: float, amp: float = 1.0) -> np.ndarray:
    time = t(duration)
    signal = np.zeros_like(time)
    for ratio, weight in ((1.0, 1.0), (2.01, 0.42), (2.98, 0.2), (4.1, 0.08)):
        signal += np.sin(2 * np.pi * freq * ratio * time) * weight * np.exp(-time * (2.2 + ratio))
    return signal * amp


def add(target: np.ndarray, signal: np.ndarray, at: float = 0.0, gain: float = 1.0) -> None:
    """Mix `signal` into `target` at `at` seconds, clipping to the buffer."""
    start = int(at * SR)
    end = min(len(target), start + len(signal))
    if end > start:
        target[start:end] += signal[: end - start] * gain


def lowpass(signal: np.ndarray, alpha: float) -> np.ndarray:
    out = np.zeros_like(signal)
    value = 0.0
    for i, sample in enumerate(signal):
        value += alpha * (sample - value)
        out[i] = value
    return out


def reverb(signal: np.ndarray, delay: float = 0.09, decay: float = 0.28, taps: int = 4) -> np.ndarray:
    out = signal.copy()
    step = int(delay * SR)
    for tap in range(1, taps + 1):
        shifted = np.zeros_like(signal)
        offset = step * tap
        if offset < len(signal):
            shifted[offset:] = signal[:-offset] * (decay ** tap)
        out += shifted
    return out


def sfx() -> None:
    # interface
    click = tone(940, 0.06, 1.0) * env(0.06, 0.002, 0.05)
    write(SFX / "ui_click.wav", reverb(click, 0.02, 0.15, 2))
    back = np.zeros(int(0.1 * SR))
    add(back, tone(520, 0.09, 1.0) * env(0.09, 0.005, 0.08))
    add(back, tone(380, 0.06, 0.7) * env(0.06, 0.002, 0.05), 0.03)
    write(SFX / "ui_back.wav", reverb(back, 0.03, 0.2, 2))

    # placing a cat: a warm two-note marimba
    place = np.zeros(int(0.26 * SR))
    add(place, tone(659.25, 0.22, 0.9, "soft") * env(0.22, 0.004, 0.2, 2.4))
    add(place, tone(987.77, 0.16, 0.45, "soft") * env(0.16, 0.002, 0.15, 2.0), 0.015)
    write(SFX / "place.wav", reverb(place, 0.05, 0.22, 3))

    unplace = np.zeros(int(0.16 * SR))
    add(unplace, tone(440, 0.13, 0.7, "soft") * env(0.13, 0.003, 0.12))
    add(unplace, tone(294, 0.1, 0.5) * env(0.1, 0.002, 0.09), 0.01)
    write(SFX / "unplace.wav", reverb(unplace, 0.03, 0.15, 2))

    # paw note: a dry tick with a little body
    tick = tone(1500, 0.04, 0.6) * env(0.04, 0.001, 0.035, 3.0)
    tick += np.random.default_rng(4).normal(0, 0.08, len(tick)) * env(0.04, 0.001, 0.03)
    write(SFX / "mark.wav", tick)

    # wrong guess: a soft, low "no" rather than a buzzer
    wrong = tone(146.83, 0.26, 1.0, "triangle") * env(0.26, 0.006, 0.24)
    wrong += tone(110, 0.26, 0.6) * env(0.26, 0.006, 0.24)
    write(SFX / "wrong.wav", lowpass(wrong, 0.22))

    # hint: a small three-note chime
    hint = np.zeros(int(0.6 * SR))
    for index, freq in enumerate((783.99, 987.77, 1318.5)):
        start = int(index * 0.07 * SR)
        note = bell(freq, 0.5, 0.55)
        hint[start:start + len(note)] += note[: len(hint) - start]
    write(SFX / "hint.wav", reverb(hint, 0.07, 0.3, 4))

    # victory: a warm arpeggio that resolves
    win = np.zeros(int(1.4 * SR))
    for index, freq in enumerate((523.25, 659.25, 783.99, 1046.5)):
        note = np.zeros(int(1.15 * SR))
        add(note, bell(freq, 1.1, 0.5))
        add(note, tone(freq / 2, 1.0, 0.16, "soft") * env(1.0, 0.01, 0.9))
        add(win, note, index * 0.11)
    write(SFX / "win.wav", reverb(win, 0.1, 0.34, 4))

    star = bell(1318.5, 0.45, 0.7)
    write(SFX / "star.wav", reverb(star, 0.08, 0.3, 3))


CHORDS = [
    (261.63, 329.63, 392.0, 493.88),   # Cmaj7
    (220.0, 261.63, 329.63, 392.0),    # Am7
    (174.61, 220.0, 261.63, 329.63),   # Fmaj7
    (196.0, 246.94, 293.66, 392.0),    # G
]


def pad_chord(freqs, duration: float) -> np.ndarray:
    out = np.zeros(int(duration * SR))
    time = t(duration)
    for index, freq in enumerate(freqs):
        for detune in (-0.12, 0.0, 0.12):
            signal = np.sin(2 * np.pi * (freq + detune) * time + index)
            out += signal * 0.11
        out += np.sin(2 * np.pi * freq * 2 * time) * 0.02
    swell = np.sin(np.linspace(0, np.pi, len(out))) ** 0.7
    return out * swell


def pluck(freq: float, duration: float, amp: float = 0.5) -> np.ndarray:
    time = t(duration)
    signal = np.sin(2 * np.pi * freq * time) + 0.4 * np.sin(2 * np.pi * freq * 2 * time)
    return signal * np.exp(-time * 5.5) * amp


def music_cozy() -> None:
    beat = 60.0 / 66.0
    bars = 8
    total = beat * 4 * bars
    mix = np.zeros(int(total * SR))
    melody = [0, 2, 1, 3, 2, 1, 0, 2]
    for bar in range(bars):
        chord = CHORDS[bar % len(CHORDS)]
        start = int(bar * beat * 4 * SR)
        block = pad_chord(chord, beat * 4 + 0.6)
        mix[start:start + len(block)] += block[: len(mix) - start]
        for step in range(8):
            if (bar + step) % 3 == 0:
                continue
            index = (bar * 2 + step) % len(chord)
            freq = chord[index] * 2
            note = pluck(freq, 0.7, 0.18)
            at = start + int(step * beat * 0.5 * SR)
            mix[at:at + len(note)] += note[: len(mix) - at]
    # a slow purr underneath
    purr = np.sin(2 * np.pi * 42 * t(total)) * 0.02
    purr *= 0.6 + 0.4 * np.sin(2 * np.pi * 2.0 * t(total))
    mix += purr
    fade = int(0.04 * SR)
    mix[:fade] *= np.linspace(0, 1, fade)
    mix[-fade:] *= np.linspace(1, 0, fade)
    write(MUSIC / "cozy.wav", reverb(mix, 0.13, 0.3, 3))


def music_focus() -> None:
    beat = 60.0 / 76.0
    bars = 8
    total = beat * 4 * bars
    mix = np.zeros(int(total * SR))
    scale = [261.63, 293.66, 329.63, 392.0, 440.0]
    pattern = [0, 2, 4, 2, 1, 3, 4, 3]
    for bar in range(bars):
        chord = CHORDS[(bar * 2) % len(CHORDS)]
        start = int(bar * beat * 4 * SR)
        block = pad_chord([f / 2 for f in chord], beat * 4 + 0.5) * 0.7
        mix[start:start + len(block)] += block[: len(mix) - start]
        for step in range(8):
            freq = scale[(pattern[step] + bar) % len(scale)] * 2
            note = pluck(freq, 0.45, 0.16)
            at = start + int(step * beat * 0.5 * SR)
            mix[at:at + len(note)] += note[: len(mix) - at]
        pulse = tone(chord[0] / 2, 0.18, 0.12, "soft") * env(0.18, 0.004, 0.17)
        at = start + int(beat * 1.0 * SR)
        mix[at:at + len(pulse)] += pulse[: len(mix) - at]
    fade = int(0.04 * SR)
    mix[:fade] *= np.linspace(0, 1, fade)
    mix[-fade:] *= np.linspace(1, 0, fade)
    write(MUSIC / "focus.wav", reverb(mix, 0.11, 0.26, 3))


def main() -> None:
    sfx()
    music_cozy()
    music_focus()


if __name__ == "__main__":
    main()
