export const NORMALIZED_SCHEMA_VERSION = 1 as const;

export interface NormalizedSegment {
  start_ms: number | null;
  end_ms: number | null;
  speaker: string | null;
  chinese: string;
  english: string;
  confidence: number | null;
}

export interface NormalizedTranscript {
  schema_version: typeof NORMALIZED_SCHEMA_VERSION;
  sample_id: string;
  provider: {
    name: 'soniox';
    region: 'us';
    model: string;
    transcription_id: string;
    file_id: string | null;
  };
  audio_duration_ms: number | null;
  translation: {
    mode: 'one_way';
    from: string | null;
    to: string;
  };
  segments: NormalizedSegment[];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function fail(message: string): never {
  throw new Error(`Invalid normalized transcript: ${message}`);
}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) fail(message);
}

function assertNullableMilliseconds(value: unknown, field: string): void {
  assert(
    value === null ||
      (typeof value === 'number' && Number.isInteger(value) && value >= 0),
    `${field} must be a non-negative integer or null`,
  );
}

export function assertNormalizedTranscript(
  value: unknown,
): asserts value is NormalizedTranscript {
  assert(isRecord(value), 'root must be an object');
  assert(value.schema_version === NORMALIZED_SCHEMA_VERSION, 'schema_version must be 1');
  assert(typeof value.sample_id === 'string' && /^\d{5}$/.test(value.sample_id), 'sample_id must be five digits');
  assert(isRecord(value.provider), 'provider must be an object');
  assert(value.provider.name === 'soniox', 'provider.name must be soniox');
  assert(value.provider.region === 'us', 'provider.region must be us');
  assert(typeof value.provider.model === 'string' && value.provider.model.length > 0, 'provider.model is required');
  assert(typeof value.provider.transcription_id === 'string' && value.provider.transcription_id.length > 0, 'provider.transcription_id is required');
  assert(value.provider.file_id === null || (typeof value.provider.file_id === 'string' && value.provider.file_id.length > 0), 'provider.file_id must be a string or null');
  assertNullableMilliseconds(value.audio_duration_ms, 'audio_duration_ms');
  assert(isRecord(value.translation), 'translation must be an object');
  assert(value.translation.mode === 'one_way', 'translation.mode must be one_way');
  assert(value.translation.from === null || (typeof value.translation.from === 'string' && value.translation.from.length > 0), 'translation.from must be a string or null');
  assert(typeof value.translation.to === 'string' && value.translation.to.length > 0, 'translation.to is required');
  assert(Array.isArray(value.segments), 'segments must be an array');

  for (const [index, segment] of value.segments.entries()) {
    assert(isRecord(segment), `segments[${index}] must be an object`);
    const startMs = segment.start_ms;
    const endMs = segment.end_ms;
    assertNullableMilliseconds(startMs, `segments[${index}].start_ms`);
    assertNullableMilliseconds(endMs, `segments[${index}].end_ms`);
    if (typeof startMs === 'number' && typeof endMs === 'number') {
      assert(endMs >= startMs, `segments[${index}] end_ms precedes start_ms`);
    }
    assert(segment.speaker === null || typeof segment.speaker === 'string', `segments[${index}].speaker must be a string or null`);
    assert(typeof segment.chinese === 'string', `segments[${index}].chinese must be a string`);
    assert(typeof segment.english === 'string', `segments[${index}].english must be a string`);
    assert(
      segment.confidence === null ||
        (typeof segment.confidence === 'number' && Number.isFinite(segment.confidence) && segment.confidence >= 0 && segment.confidence <= 1),
      `segments[${index}].confidence must be between 0 and 1 or null`,
    );
  }
}
