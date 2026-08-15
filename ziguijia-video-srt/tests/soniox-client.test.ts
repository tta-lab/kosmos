import { afterEach, describe, expect, test } from 'bun:test';
import {
  createSonioxClient,
  PILOT_TIMEOUT_MS,
  SONIOX_CONTEXT,
  SONIOX_MODEL,
  type TranslationRequest,
} from '../src/soniox-client';

const originalFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = originalFetch;
});

describe('official Soniox client adapter', () => {
  test('uses the US endpoint and serializes the required SDK request settings', async () => {
    const calls: Array<{ url: string; method: string; body: unknown }> = [];
    globalThis.fetch = (async (input, init) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
      const method = init?.method ?? 'GET';
      const body = init?.body instanceof FormData
        ? '[multipart]'
        : typeof init?.body === 'string'
          ? JSON.parse(init.body)
          : null;
      calls.push({ url, method, body });

      if (url.endsWith('/v1/files')) {
        return Response.json({
          id: 'file-1',
          filename: 'audio.wav',
          size: 2,
          created_at: '2024-01-01T00:00:00Z',
          client_reference_id: null,
        });
      }
      if (url.endsWith('/v1/transcriptions') && method === 'POST') {
        return Response.json({
          id: 'transcription-1',
          status: 'completed',
          created_at: '2024-01-01T00:00:00Z',
          model: SONIOX_MODEL,
          audio_url: null,
          file_id: 'file-1',
          filename: 'audio.wav',
          language_hints: ['zh'],
          enable_speaker_diarization: true,
          enable_language_identification: true,
          audio_duration_ms: 1000,
          error_type: null,
          error_message: null,
          webhook_url: null,
          webhook_auth_header_name: null,
          webhook_auth_header_value: null,
          webhook_status_code: null,
          client_reference_id: '00111',
          context: SONIOX_CONTEXT,
        });
      }
      if (url.endsWith('/v1/transcriptions/transcription-1/transcript')) {
        return Response.json({
          id: 'transcription-1',
          text: '你好',
          tokens: [
            {
              text: '你好',
              start_ms: 100,
              end_ms: 500,
              confidence: 0.9,
              speaker: '1',
              language: 'zh',
              translation_status: 'original',
            },
            {
              text: 'Hello',
              confidence: 0.99,
              language: 'en',
              source_language: 'zh',
              translation_status: 'translation',
            },
          ],
        });
      }
      throw new Error(`Unexpected fake SDK request: ${method} ${url}`);
    }) as typeof fetch;

    const request: TranslationRequest = {
      file: new Uint8Array([1, 2]),
      filename: 'audio.wav',
      client_reference_id: '00111',
      model: SONIOX_MODEL,
      from: 'zh',
      to: 'en',
      enable_speaker_diarization: true,
      context: SONIOX_CONTEXT,
      wait: true,
      fetch_translation: true,
      wait_options: { timeout_ms: PILOT_TIMEOUT_MS },
      timeout_ms: PILOT_TIMEOUT_MS,
    };
    const job = await createSonioxClient('test-secret').translate(request);
    const transcriptionCall = calls.find(
      (call) => call.url.endsWith('/v1/transcriptions') && call.method === 'POST',
    );

    expect(calls[0]?.url).toBe('https://api.soniox.com/v1/files');
    expect(transcriptionCall?.body).toMatchObject({
      model: SONIOX_MODEL,
      client_reference_id: '00111',
      language_hints: ['zh'],
      language_hints_strict: true,
      enable_language_identification: true,
      enable_speaker_diarization: true,
      translation: { type: 'one_way', target_language: 'en' },
      context: SONIOX_CONTEXT,
    });
    expect(job.toJSON().client_reference_id).toBe('00111');
    expect(job.translation?.mode).toBe('one_way');
    if (job.translation?.mode === 'one_way') {
      expect(job.translation.to).toBe('en');
    }
    expect(job.transcript?.tokens).toHaveLength(2);
  });
});
