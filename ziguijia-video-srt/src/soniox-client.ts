import {
  SonioxNodeClient,
  type SonioxTranslation,
  type SonioxTranslationJob,
  type SonioxTranscript,
  type SonioxTtsApi,
  type TranslateOptions,
} from '@soniox/node';

export const SONIOX_MODEL = 'stt-async-v5';
export const SONIOX_REGION = 'us';
export const PILOT_TIMEOUT_MS = 30 * 60 * 1000;

export const SONIOX_CONTEXT = {
  general: [
    { key: 'domain', value: 'Chinese Buddhist teaching' },
    { key: 'audience', value: 'Possible audience questions' },
  ],
} satisfies { general: Array<{ key: string; value: string }> };

export type TranslationRequest = TranslateOptions;
export type OneWayTranslation = Extract<SonioxTranslation, { mode: 'one_way' }>;

/**
 * The production client uses the official SDK job and translation types. This
 * is only the narrow evidence surface needed by the runner and its fake client.
 */
export type TranslationJob = Pick<
  SonioxTranslationJob,
  'id' | 'status' | 'model' | 'file_id' | 'audio_duration_ms' | 'translation' | 'destroy'
> & {
  transcript:
    | Pick<SonioxTranscript, 'id' | 'text' | 'tokens'>
    | null
    | undefined;
  toJSON(): Record<string, unknown>;
};

export interface TranslationClient {
  translate(request: TranslationRequest): Promise<TranslationJob>;
}

/**
 * The SDK's translate helper turns `from: 'zh'` into a strict Chinese language
 * hint and always enables language identification before creating the async
 * transcription. Keeping that behavior in the official SDK avoids duplicating
 * provider request mechanics here. The fixed timeout is passed both to the
 * caller operation and to SDK polling.
 */
export function createSonioxClient(apiKey: string): TranslationClient {
  const client = new SonioxNodeClient({ api_key: apiKey, region: SONIOX_REGION });

  return {
    translate: (request) => client.stt.translate(request),
  };
}

/**
 * The same official client also exposes the TTS API (client.tts), deriving
 * its endpoint from the same region setting used for STT. Kept as a separate
 * factory so the STT translation surface stays narrow.
 */
export function createSonioxTts(apiKey: string): SonioxTtsApi {
  const client = new SonioxNodeClient({ api_key: apiKey, region: SONIOX_REGION });
  return client.tts;
}
