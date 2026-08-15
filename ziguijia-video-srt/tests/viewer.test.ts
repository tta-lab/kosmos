import { afterEach, describe, expect, test } from 'bun:test';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { startViewerServer } from '../src/viewer';

const temporaryDirectories: string[] = [];
const servers: Array<{ stop(closeActiveConnections?: boolean): void | Promise<void> }> = [];

afterEach(async () => {
  await Promise.all(servers.splice(0).map((server) => Promise.resolve(server.stop(true))));
  await Promise.all(
    temporaryDirectories.splice(0).map((directory) => rm(directory, { recursive: true, force: true })),
  );
});

describe('local Soniox transcript viewer', () => {
  test('serves the HTML shell, speaker transcript, and seekable audio ranges', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-viewer-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const runsRoot = join(root, 'soniox-runs');
    await mkdir(join(samplesRoot, '00001'), { recursive: true });
    await mkdir(join(runsRoot, '00001'), { recursive: true });
    await writeFile(join(samplesRoot, '00001', 'audio.wav'), new Uint8Array([0, 1, 2, 3, 4, 5]));
    await writeFile(
      join(samplesRoot, '00001', 'metadata.json'),
      JSON.stringify({ title: 'Viewer fixture', date: '2026-01-01', video_duration_seconds: 2 }),
    );
    await writeFile(
      join(runsRoot, '00001', 'normalized.json'),
      JSON.stringify({
        schema_version: 1,
        sample_id: '00001',
        provider: {
          name: 'soniox',
          region: 'us',
          model: 'stt-async-v5',
          transcription_id: 'viewer-transcription',
          file_id: null,
        },
        audio_duration_ms: 2000,
        translation: { mode: 'one_way', from: 'zh', to: 'en' },
        segments: [
          {
            start_ms: 0,
            end_ms: 1000,
            speaker: '1',
            chinese: '你好。',
            english: 'Hello.',
            confidence: 0.9,
          },
          {
            start_ms: 1000,
            end_ms: 2000,
            speaker: '2',
            chinese: '谢谢。',
            english: 'Thank you.',
            confidence: 0.8,
          },
        ],
      }),
    );

    const server = startViewerServer({ samplesRoot, runsRoot, port: 0 });
    servers.push(server);
    const base = server.url;

    const page = await fetch(base);
    expect(page.status).toBe(200);
    expect(await page.text()).toContain('Transcript / speaker map');

    const list = await (await fetch(new URL('/api/samples', base))).json() as Array<{ id: string; title: string; date: string; video_duration_seconds: number; audio_duration_ms: number; segment_count: number; speakers: string[] }>;
    expect(list).toEqual([
      { id: '00001', title: 'Viewer fixture', date: '2026-01-01', video_duration_seconds: 2, audio_duration_ms: 2000, segment_count: 2, speakers: ['1', '2'] },
    ]);

    const detail = await (await fetch(new URL('/api/samples/00001', base))).json() as { transcript: { segments: Array<{ speaker: string }> } };
    expect(detail.transcript.segments.map((segment) => segment.speaker)).toEqual(['1', '2']);

    const audio = await fetch(new URL('/api/samples/00001/audio', base), { headers: { range: 'bytes=1-3' } });
    expect(audio.status).toBe(206);
    expect(audio.headers.get('content-range')).toBe('bytes 1-3/6');
    expect(new Uint8Array(await audio.arrayBuffer())).toEqual(new Uint8Array([1, 2, 3]));
  });
});
