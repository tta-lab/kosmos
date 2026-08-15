import { describe, expect, test } from 'bun:test';
import type { SonioxTtsApi } from '@soniox/node';
import {
  DEFAULT_FORMAT,
  DEFAULT_LANGUAGE,
  DEFAULT_VOICE,
  runTts,
} from '../src/tts';

function fakeTts(record: { calls: Array<{ output: unknown; options: Record<string, unknown> }> }) {
  const api = {
    generateToFile: async (output: unknown, options: Record<string, unknown>) => {
      record.calls.push({ output, options });
      return 4321;
    },
  } as unknown as SonioxTtsApi;
  return () => api;
}

describe('TTS CLI', () => {
  test('synthesizes to the output path with defaults', async () => {
    const record = { calls: [] as Array<{ output: unknown; options: Record<string, unknown> }> };
    const result = await runTts(['Hello from OpenClaw', '/tmp/out.mp3'], {
      env: { SONIOX_API_KEY: 'secret-key' },
      ttsFactory: fakeTts(record),
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('4321 bytes');
    expect(record.calls).toHaveLength(1);
    expect(record.calls[0]!.output).toBe('/tmp/out.mp3');
    expect(record.calls[0]!.options).toMatchObject({
      text: 'Hello from OpenClaw',
      voice: DEFAULT_VOICE,
      language: DEFAULT_LANGUAGE,
      audio_format: DEFAULT_FORMAT,
    });
  });

  test('honors explicit options', async () => {
    const record = { calls: [] as Array<{ output: unknown; options: Record<string, unknown> }> };
    const result = await runTts(
      ['--voice', 'Zephyr', '--language', 'zh', '--format', 'wav', '--speed', '1.2', '你好', '/tmp/out.wav'],
      { env: { SONIOX_API_KEY: 'k' }, ttsFactory: fakeTts(record) },
    );
    expect(result.exitCode).toBe(0);
    expect(record.calls[0]!.options).toMatchObject({
      text: '你好',
      voice: 'Zephyr',
      language: 'zh',
      audio_format: 'wav',
      speed: 1.2,
    });
  });

  test('requires SONIOX_API_KEY', async () => {
    const result = await runTts(['hi', '/tmp/out.mp3'], { env: {} });
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain('SONIOX_API_KEY is required');
  });

  test('rejects unknown options and unsupported formats', async () => {
    const unknown = await runTts(['--bogus', 'hi', '/tmp/out.mp3'], {
      env: { SONIOX_API_KEY: 'k' },
      ttsFactory: fakeTts({ calls: [] }),
    });
    expect(unknown.exitCode).toBe(1);
    expect(unknown.stderr).toContain('Unknown option');

    const badFormat = await runTts(['--format', 'ogg', 'hi', '/tmp/out.mp3'], {
      env: { SONIOX_API_KEY: 'k' },
      ttsFactory: fakeTts({ calls: [] }),
    });
    expect(badFormat.exitCode).toBe(1);
    expect(badFormat.stderr).toContain('unsupported audio format');
  });
});
