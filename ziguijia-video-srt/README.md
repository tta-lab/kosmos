# Ziguijia video subtitle translation

Chinese-to-English subtitle translation and review workspace.

## Layout

```text
materials/
├── archives/                 # Original downloaded ZIP files; preserve unchanged
├── instructions/             # Translation and review PDFs
├── terminology/              # Chinese-English keyword reference
├── subtitles/                # 28 extracted bilingual subtitle files
└── references/
    ├── dubbing-samples/       # V1–V5 examples plus revised V5
    └── questioner/            # Example containing an inserted questioner segment
samples/<subtitle_id>/         # Video/audio verification samples and mapping metadata
AGENTS.md                      # Workflow rules for agents
```

Each sample directory may contain `video.mp4`, `audio.wav`, `subtitle.zh+en.srt`, and `metadata.json`. The subtitle filename ID is used directly as the ziguijia shoot ID, including leading zeroes.

Original archives remain under `materials/archives/`; extracted files are the working copies.

## Soniox quality pilot

The standalone Bun CLI sends selected verified sample WAV files to Soniox's US async API. It does not modify `samples/` or generate SRT files.

```sh
bun install
cp .env.example .env
# Set SONIOX_API_KEY in .env, then:
bun run soniox -- 00111 00173 00174
```

The command accepts one or more explicit five-digit sample IDs. It validates every ID, source audio file, and `SONIOX_API_KEY` before making requests, runs at most four samples concurrently, and exits nonzero if any sample fails.

Generated evidence is written under `soniox-runs/<sample_id>/`:

- `raw.json` — a provider-evidence envelope assembled from SDK transcription metadata, the transcript token payload, and the structured translation response; it is not a single untouched provider response and contains no normalized segments.
- `normalized.json` — versioned bilingual segments with source timing, local speaker labels, and source confidence.
- `review.md` — readable timestamped transcript for quality review.

Use `--samples-root <path>` or `--output-root <path>` when working with temporary roots. The command rejects an output root equal to or nested under the samples root so supplied inputs cannot be replaced. Successful reruns publish a staged replacement for only the selected generated sample directory; ordinary write failures remove staging and attempt to restore the prior directory. Transient staging files are ignored by Git.

## Soniox TTS CLI

Synthesize speech from text with Soniox's TTS REST API and write an audio file. OpenClaw's `tts-local-cli` provider calls this script for speech output.

```sh
bun run src/tts.ts "Hello from OpenClaw" out.mp3
bun run src/tts.ts --voice Adrian --language en --format mp3 "你好" out.mp3
```

Requires `SONIOX_API_KEY` in `.env` or the environment. Options: `--voice` (default `Adrian`), `--language` (default `en`), `--format` (`wav|mp3|opus|aac|flac|pcm_*`, default `mp3`), `--speed` (0.7–1.3), `--help`.

## Local transcript viewer

After the live pilot has produced `soniox-runs/`, start the local review page:

```sh
bun run viewer
# open http://127.0.0.1:4319
```

The page presents the selected sample's WAV audio on the left and a scrollable Chinese/English transcript on the right. Each transcript block shows the Soniox-local speaker label (`Speaker 1`, `Speaker 2`, etc.), confidence, and timestamp; clicking a block seeks the audio, and playback follows the active block. Set `PORT=4320` to use another port.
