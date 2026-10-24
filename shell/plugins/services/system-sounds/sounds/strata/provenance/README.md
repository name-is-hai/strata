# Sound provenance

`mapping.tsv` in the parent folder records the selected theme for every event.
`processing.tsv` records upstream cue names and gains from the local pack preparation.
`originals/` contains the audio before loudness adjustment (WAV cues had already
been converted to Ogg Vorbis). The event audio in the parent folder is the
prepared sound. Classic and Glass audio was copied unchanged.

Positive gains were applied with FFmpeg, a maximum gain of 24 dB, a -1.5 dBFS
peak limiter, 48 kHz output, and Vorbis quality 7:

```sh
ffmpeg -i original.ogg -af "volume=GAINdB,alimiter=limit=0.841395:level=false:latency=true" -ar 48000 -c:a libvorbis -q:a 7 event.ogg
```

The originals, edits, license notices and attribution are supplied together.

Upstream sources:

- Classic / Glass: https://github.com/Dielerorn/omarchy-system-sounds (MIT)
- Ocean: https://github.com/KDE/ocean-sound-theme
- Oxygen: https://github.com/KDE/oxygen-sounds
- elementary: https://github.com/elementary/sound-theme
- Freedesktop: https://gitlab.freedesktop.org/xdg/xdg-sound-theme
- Yaru: https://github.com/ubuntu/yaru

The elementary pack uses Oxygen `outcome-success` for theme-change and Oxygen
device cues for Bluetooth. Its authentication cue originates from Ocean.
Beep and reminder were unspecified and use Freedesktop to complete all 19 events.
Per-event `.license` files and `LICENSES/` retain the upstream terms.
