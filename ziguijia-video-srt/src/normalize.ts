import {
  SONIOX_MODEL,
  SONIOX_REGION,
  type OneWayTranslation,
  type TranslationJob,
} from './soniox-client';
import type { TranscriptToken } from '@soniox/node';
import {
  NORMALIZED_SCHEMA_VERSION,
  type NormalizedTranscript,
} from './schema';

// Raw evidence keeps provider/SDK payloads separate from the normalized contract.
export interface RawSonioxArtifact {
  transcription: Record<string, unknown>;
  transcript: TranslationJob['transcript'];
  translation: OneWayTranslation | null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function providerError(message: string): never {
  throw new Error(`Invalid Soniox response: ${message}`);
}

function assertProvider(condition: unknown, message: string): asserts condition {
  if (!condition) providerError(message);
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function validateToken(token: unknown, location: string): asserts token is TranscriptToken {
  assertProvider(isRecord(token), `${location} must be an object`);
  assertProvider(typeof token.text === 'string', `${location}.text is required`);
  if (token.confidence !== undefined) {
    assertProvider(
      isFiniteNumber(token.confidence) && token.confidence >= 0 && token.confidence <= 1,
      `${location}.confidence must be between 0 and 1`,
    );
  }
  if (token.start_ms !== undefined) {
    assertProvider(isFiniteNumber(token.start_ms) && token.start_ms >= 0, `${location}.start_ms must be non-negative`);
  }
  if (token.end_ms !== undefined) {
    assertProvider(isFiniteNumber(token.end_ms) && token.end_ms >= 0, `${location}.end_ms must be non-negative`);
  }
}

type OneWaySegment = OneWayTranslation['segments'][number];

function validateSegment(segment: unknown, location: string): asserts segment is OneWaySegment {
  assertProvider(isRecord(segment), `${location} must be an object`);
  assertProvider(typeof segment.from === 'string' && segment.from.length > 0, `${location}.from is required`);
  assertProvider(typeof segment.original_text === 'string', `${location}.original_text is required`);
  assertProvider(Array.isArray(segment.original_tokens), `${location}.original_tokens are required`);
  for (const [index, token] of segment.original_tokens.entries()) {
    validateToken(token, `${location}.original_tokens[${index}]`);
  }
  assertProvider(
    typeof segment.translation_text === 'string' && segment.translation_text.trim().length > 0,
    `${location}.translation_text is required`,
  );
  if (segment.to !== undefined) {
    assertProvider(segment.to === 'en', `${location}.to must be en`);
  }
  if (segment.translation_tokens !== undefined) {
    assertProvider(Array.isArray(segment.translation_tokens), `${location}.translation_tokens must be an array`);
    for (const [index, token] of segment.translation_tokens.entries()) {
      validateToken(token, `${location}.translation_tokens[${index}]`);
    }
  }
}

function oneWayTranslation(value: TranslationJob['translation']): OneWayTranslation {
  assertProvider(value !== null && value !== undefined, 'structured translation is missing');
  assertProvider(value.mode === 'one_way', 'structured translation must be one_way');
  assertProvider(value.to === 'en', 'structured translation target must be en');
  assertProvider(Array.isArray(value.segments), 'translation segments are missing');
  for (const [index, segment] of value.segments.entries()) {
    validateSegment(segment, `translation.segments[${index}]`);
  }
  return value;
}

export function validateSonioxJob(job: TranslationJob): OneWayTranslation {
  assertProvider(typeof job.id === 'string' && job.id.length > 0, 'transcription id is required');
  assertProvider(job.status === 'completed', `status must be completed (received ${job.status})`);
  assertProvider(job.model === SONIOX_MODEL, `model must be ${SONIOX_MODEL}`);
  assertProvider(
    job.file_id === null ||
      job.file_id === undefined ||
      (typeof job.file_id === 'string' && job.file_id.length > 0),
    'file id must be a non-empty string or null',
  );
  assertProvider(typeof job.toJSON === 'function', 'metadata serialization is unavailable');
  assertProvider(isRecord(job.toJSON()), 'metadata response must be an object');
  assertProvider(job.transcript !== null && job.transcript !== undefined, 'transcript is missing');
  assertProvider(typeof job.transcript.id === 'string', 'transcript id is missing');
  assertProvider(typeof job.transcript.text === 'string', 'transcript text is missing');
  assertProvider(Array.isArray(job.transcript.tokens), 'transcript tokens are missing');
  for (const [index, token] of job.transcript.tokens.entries()) {
    validateToken(token, `transcript.tokens[${index}]`);
  }
  return oneWayTranslation(job.translation);
}

export function buildRawSonioxArtifact(job: TranslationJob): RawSonioxArtifact {
  const translation = validateSonioxJob(job);
  return {
    transcription: job.toJSON(),
    transcript: job.transcript!,
    translation,
  };
}

function sourceTiming(tokens: TranscriptToken[]): { start_ms: number | null; end_ms: number | null } {
  const first = tokens[0];
  const last = tokens.at(-1);
  return {
    start_ms: isFiniteNumber(first?.start_ms) ? first.start_ms : null,
    end_ms: isFiniteNumber(last?.end_ms) ? last.end_ms : null,
  };
}

function sourceSpeaker(tokens: TranscriptToken[]): string | null {
  const speaker = tokens.find((token) => typeof token.speaker === 'string' && token.speaker.length > 0)?.speaker;
  return speaker ?? null;
}

function sourceConfidence(tokens: TranscriptToken[]): number | null {
  const confidence = tokens
    .map((token) => token.confidence)
    .filter(isFiniteNumber);
  if (confidence.length === 0) return null;
  return confidence.reduce((sum, value) => sum + value, 0) / confidence.length;
}

export function normalizeSonioxJob(
  sampleId: string,
  job: TranslationJob,
): NormalizedTranscript {
  const translation = validateSonioxJob(job);
  const segments = translation.segments.map((segment) => {
    const timing = sourceTiming(segment.original_tokens);
    const english = segment.translation_text;
    assertProvider(
      typeof english === 'string' && english.trim().length > 0,
      'translation_text is required',
    );
    return {
      ...timing,
      speaker: sourceSpeaker(segment.original_tokens),
      chinese: segment.original_text,
      english,
      confidence: sourceConfidence(segment.original_tokens),
    };
  });

  return {
    schema_version: NORMALIZED_SCHEMA_VERSION,
    sample_id: sampleId,
    provider: {
      name: 'soniox',
      region: SONIOX_REGION,
      model: job.model,
      transcription_id: job.id,
      file_id: job.file_id ?? null,
    },
    audio_duration_ms: isFiniteNumber(job.audio_duration_ms) ? job.audio_duration_ms : null,
    translation: {
      mode: 'one_way',
      from: translation.from ?? null,
      to: translation.to,
    },
    segments,
  };
}
