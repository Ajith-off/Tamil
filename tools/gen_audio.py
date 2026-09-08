"""Synthesizes placeholder audio for the app — no downloads, no third-party
recordings, nothing copyrighted. Pure sine-wave tones on a pentatonic scale
(so nothing can land dissonant), quiet and gentle by design for a 4-8 year
old audience (CLAUDE.md section 11: no jarring stings anywhere in the app).

These are deliberately placeholders, the same way CLAUDE.md's audio section
already plans for letter sounds: a real composer's recordings can replace any
file here later with zero code change, since AudioService only ever asks for
a path under assets/audio/.

Run: python tools/gen_audio.py
Writes:
  assets/audio/sfx/click.wav        - a short bell "ting"
  assets/audio/sfx/celebration.wav  - a cheerful three-note "ta-da"
  assets/audio/music/general_loop.wav - a melodic loop for most screens
  assets/audio/music/game_loop.wav    - the same family, a touch livelier for play
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100

# C pentatonic (C D E G A), across two octaves — every combination of notes
# from this scale is consonant, so nothing generated here can clash.
NOTE_FREQS = {
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
}


def _envelope(n, attack, release):
    """Linear fade in/out so every tone starts and ends at silence — the
    thing that turns a sine wave into an audible click of its own."""
    env = [1.0] * n
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    for i in range(a):
        env[i] = i / a
    for i in range(r):
        env[n - 1 - i] = i / r
    return env


def _tone(freq, duration, amplitude=0.22, attack=0.08, release=0.35, harmonic=0.15):
    """A sine tone with a soft second harmonic — rounder and less clinical
    than a bare sine, still nowhere near a harsh synth lead."""
    n = int(SAMPLE_RATE * duration)
    env = _envelope(n, attack, release)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        v = math.sin(2 * math.pi * freq * t)
        v += harmonic * math.sin(2 * math.pi * freq * 2 * t)
        samples.append(v * amplitude * env[i])
    return samples


def _bell(freq, duration, amplitude=0.24, partial_ratio=2.4, partial_mix=0.35):
    """A fundamental plus a slightly inharmonic upper partial, decaying
    faster than the fundamental — the two together read as a metallic
    "ting" rather than a plain sine, without needing anything but math.sin.
    """
    n = int(SAMPLE_RATE * duration)
    attack_n = max(1, int(n * 0.01))
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = (i / attack_n) if i < attack_n else math.exp(-3.2 * (t - attack_n / SAMPLE_RATE))
        partial_env = math.exp(-7.0 * t)
        v = math.sin(2 * math.pi * freq * t)
        v += partial_mix * partial_env * math.sin(2 * math.pi * freq * partial_ratio * t)
        samples.append(v * amplitude * env)
    return samples


def _silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def _mix(*tracks):
    """Sums same-length or ragged tracks, clamped so nothing clips."""
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, v in enumerate(track):
            out[i] += v
    return [max(-1.0, min(1.0, v)) for v in out]


def _sequence(notes_and_durations, gap=0.0, **tone_kwargs):
    """Concatenates tones back to back, e.g. a melody line."""
    out = []
    for note, duration in notes_and_durations:
        out.extend(_tone(NOTE_FREQS[note], duration, **tone_kwargs))
        if gap:
            out.extend(_silence(gap))
    return out


def _loop_pattern(notes_and_durations, repeats, **tone_kwargs):
    one = _sequence(notes_and_durations, gap=0.06, **tone_kwargs)
    return one * repeats


def _write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(v * 32767)) for v in samples)
        f.writeframes(frames)
    print(f"wrote {path} ({len(samples) / SAMPLE_RATE:.2f}s)")


def main():
    root = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

    # A short bell "ting" — bright enough to feel like a response to the
    # tap, quiet enough not to compete with the music underneath it.
    _write_wav(
        os.path.join(root, "sfx", "click.wav"),
        _bell(NOTE_FREQS["C5"] * 2, 0.32, amplitude=0.24),
    )

    # A cheerful three-note "ta-da" — the "Yay!" moment on finishing a letter
    # or clearing a word.
    _write_wav(
        os.path.join(root, "sfx", "celebration.wav"),
        _sequence(
            [("C5", 0.16), ("E5", 0.16), ("G5", 0.32)],
            gap=0.02,
            amplitude=0.28,
            attack=0.03,
            release=0.5,
        ),
    )

    # General background loop — same melodic family as the game loop below
    # rather than a sparse pad, just unhurried: every screen but the game
    # gets a tune, not a drone.
    general = _loop_pattern(
        [
            ("C4", 0.42), ("E4", 0.42), ("G4", 0.42), ("A4", 0.42),
            ("G4", 0.42), ("E4", 0.42), ("D4", 0.42), ("C4", 0.68),
        ],
        repeats=3,
        amplitude=0.12,
        attack=0.1,
        release=0.4,
    )
    _write_wav(os.path.join(root, "music", "general_loop.wav"), general)

    # Game loop — the same family, a touch faster and brighter so it reads
    # as "play" without turning into a jingle that overstays.
    game = _loop_pattern(
        [
            ("C5", 0.32), ("D5", 0.32), ("E5", 0.32), ("G4", 0.32),
            ("A4", 0.32), ("G4", 0.32), ("E4", 0.32), ("C4", 0.5),
        ],
        repeats=2,
        amplitude=0.13,
        attack=0.06,
        release=0.3,
    )
    _write_wav(os.path.join(root, "music", "game_loop.wav"), game)


if __name__ == "__main__":
    main()
