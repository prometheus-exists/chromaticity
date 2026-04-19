# Test Audio

Fletcher-curated test tracks spanning genres and tempos for Chromaticity development.

**Not committed to git** — audio files are gitignored to keep the repo small and avoid copyright issues. Contributors who want these tracks should ask Fletcher directly.

## Track inventory (received 2026-04-19)

| Filename | Artist | Title | BPM | Format | Duration | Notes |
|----------|--------|-------|-----|--------|----------|-------|
| `notion-temporary-friends-maysev-flip-172bpm.wav` | Notion | Temporary Friends (Maysev Flip) | 172 | WAV 16-bit stereo | 2:26 | **DnB territory**. Test case for half-time feel + high-tempo handling. Bitwig Studio 6.0 export. |
| `moldae-white-noise-warrior-73bpm.flac` | Moldae | White Noise Warrior | 73 | FLAC stereo | 3:18 | **Slow tempo**. From the NETHRA compilation. Test case for low-BPM mapping + atmospheric dynamics. |
| `fletcher-unknown-2021-10.wav` | Fletcher | (untitled, 2021-10-17) | ? | WAV 24-bit stereo | 3:12 | Fletcher's own track. Logic Pro X export. BPM not tagged — let beat tracker infer. |
| `redrum-warp-2022-72bpm.flac` | Re:drum | Warp 2022 | 72 | FLAC stereo | 4:13 | From Bassboosted Edits EP. **Bass-heavy**. Test case for sub-bass energy mapping. |

## Coverage

- **Tempo range**: 72 → 172 BPM (2.4× span)
- **Genre spread**: bass-heavy electronic, slow atmospheric, DnB/halftime
- **Real-world production**: all mixed/mastered tracks, not synthetic test signals
- **Fletcher's own track** gives us a test case where the producer can judge "does the visualiser feel right?" authoritatively

## Use in render-probe Phase 1

None — Phase 1 doesn't use audio yet. These are for Phase 2 (live runtime) onward.

## Use in Phase 2+

- Beat tracking validation (aubio should agree with tagged BPM on tracks that have it)
- Spectral feature extraction test suite (each track has different spectral signature)
- CMC mapping sanity check (do warm/energetic tracks produce warm/energetic visuals?)
- Fletcher-led perceptual validation (he can judge fit authoritatively)

## Adding new tracks

When Fletcher or Xavier drops new test audio:
1. Place in this directory
2. Add a row to the table above with BPM, genre notes, why it's useful
3. Don't commit the audio itself (gitignored) — only update this README
