# Subtitle translation project

## Source model

- Treat the supplied Chinese subtitles as a provisional transcript, not immutable source truth. Preserve the original archive and record proposed source corrections separately.
- Use the five-digit filename prefix as `subtitle_id` and each SRT cue number as `cue_id`; refer to a cue as `<subtitle_id>:<cue_id>`.
- For this batch, the five-digit `subtitle_id` is the ziguijia `shoot_id`; use it exactly, including leading zeroes. For example, `00174` maps to `/shoot/00174`.

## Video mapping

Map a subtitle to a video by spoken-content evidence:

1. Open candidate pages with agent-browser at `https://ziguijia.com/chatroom/shoot/<shoot_id>`.
2. Compare the video's first spoken lines and surrounding content with the Chinese subtitle; titles and numeric similarity are supporting evidence only.
3. Record accepted and rejected candidates in `samples/<subtitle_id>/metadata.json`.
4. Call the mapping verified only when spoken content aligns. A successful download or similar title is not completion.

Known example: subtitle `00174` maps directly to shoot `00174`. Shoot `50174` and shoot `10174` are different videos; adding a prefix produces a false match.

## Sample layout

Store each verified working sample as:

```text
samples/<subtitle_id>/
├── video.mp4
├── audio.wav
├── subtitle.zh+en.srt
└── metadata.json
```

`metadata.json` must contain distinct `subtitle_id` and `shoot_id`, source URL, title, date, video duration, mapping status, alignment evidence, artifact paths, and rejected candidates when applicable.

Download through the page's official controls using agent-browser. Derive `audio.wav` with FFmpeg as 16 kHz mono PCM and verify both files with ffprobe. Replace rejected downloads rather than retaining ambiguous candidates in the active sample directory.

## Transcript and speaker review

- Use subtitle text and timestamp gaps to triage likely continuity, missing speech, topic shifts, and interruptions.
- Text-only inference may flag candidates but cannot certify speaker identity or omitted speech.
- Use audio selectively on flagged windows. Match Yang Ning's enrolled voice as `TEACHER`; classify clear non-matches as `QUESTIONER_CANDIDATE`, and low-confidence or overlapping speech as `UNKNOWN`.
- Keep standard SRT clean. Store review findings and source-correction proposals in machine-readable sidecars rather than inserting reviewer notes into subtitle cues.
- Default to preserving cue timing. Record retiming as a proposal unless the task explicitly authorizes timeline edits.

## Translation review

Use the Chinese transcript plus verified audio as semantic evidence and `materials/terminology/keywords_v2.txt` as terminology reference. Run a bounded loop: translate/edit → independent read-only review → scoped repair → verification of every changed cue. Optimize English for concise, natural spoken YouTube narration and TTS timing without changing the supported meaning.
