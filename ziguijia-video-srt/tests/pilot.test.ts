import { afterEach, describe, expect, test } from 'bun:test';
import { mkdtemp, mkdir, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  assertNormalizedTranscript,
  type NormalizedTranscript,
} from '../src/schema';
import {
  runCli,
  type TranslationClient,
  type TranslationJob,
  type TranslationRequest,
} from '../src/cli';

const temporaryDirectories: string[] = [];

afterEach(async () => {
  await Promise.all(
    temporaryDirectories.splice(0).map((directory) =>
      rm(directory, { recursive: true, force: true }),
    ),
  );
});

describe('Soniox pilot CLI', () => {
  test('processes one sample into raw, normalized, and review artifacts', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputRoot = join(root, 'soniox-runs');
    const sampleRoot = join(samplesRoot, '00001');
    await mkdir(sampleRoot, { recursive: true });
    const audioBytes = new TextEncoder().encode('fake wav bytes');
    await writeFile(join(sampleRoot, 'audio.wav'), audioBytes);
    await writeFile(
      join(sampleRoot, 'metadata.json'),
      JSON.stringify({
        subtitle_id: '00001',
        shoot_id: '00001',
        source_url: 'https://example.test/shoot/00001',
        title: 'Test sample',
        date: '2024-01-01',
        mapping_status: 'exact_id_content_match',
        video_duration_seconds: 1,
        artifacts: { audio: 'audio.wav' },
        mapping_evidence: { rule: 'fixture content match', subtitle_topic: 'Test sample' },
        rejected_candidates: [],
      }),
    );

    const events: string[] = [];
    const requests: TranslationRequest[] = [];
    const job: TranslationJob = {
      id: 'transcription-00001',
      status: 'completed',
      model: 'stt-async-v5',
      file_id: 'file-00001',
      audio_duration_ms: 2400,
      transcript: {
        id: 'transcription-00001',
        text: '你好。谢谢。',
        tokens: [
          {
            text: '你好。',
            start_ms: 1000,
            end_ms: 1500,
            confidence: 0.9,
            speaker: '1',
            language: 'zh',
            translation_status: 'original',
          },
          {
            text: '谢谢。',
            confidence: 0.8,
            speaker: '2',
            language: 'zh',
            translation_status: 'original',
          },
        ],
      },
      translation: {
        mode: 'one_way',
        from: 'zh',
        to: 'en',
        duration_ms: 2400,
        original_text: '你好。谢谢。',
        translation_text: 'Hello. Thank you.',
        segments: [
          {
            start_ms: 1000,
            end_ms: 1500,
            speaker: '1',
            from: 'zh',
            original_text: '你好。',
            original_tokens: [
              {
                text: '你好。',
                start_ms: 1000,
                end_ms: 1500,
                confidence: 0.9,
                speaker: '1',
                language: 'zh',
                translation_status: 'original',
              },
            ],
            to: 'en',
            translation_text: 'Hello.',
            translation_tokens: [
              {
                text: 'Hello.',
                confidence: 0.99,
                language: 'en',
                source_language: 'zh',
                translation_status: 'translation',
              },
            ],
          },
          {
            speaker: '2',
            from: 'zh',
            original_text: '谢谢。',
            original_tokens: [
              {
                text: '谢谢。',
                confidence: 0.8,
                speaker: '2',
                language: 'zh',
                translation_status: 'original',
              },
            ],
            to: 'en',
            translation_text: 'Thank you.',
            translation_tokens: [
              {
                text: 'Thank you.',
                confidence: 0.98,
                language: 'en',
                source_language: 'zh',
                translation_status: 'translation',
              },
            ],
          },
        ],
      },
      toJSON: () => ({
        id: 'transcription-00001',
        status: 'completed',
        model: 'stt-async-v5',
        file_id: 'file-00001',
        filename: 'audio.wav',
        client_reference_id: '00001',
        language_hints: ['zh'],
        enable_language_identification: true,
        enable_speaker_diarization: true,
        audio_duration_ms: 2400,
      }),
      destroy: async () => {
        events.push('cleanup');
      },
    };
    const client: TranslationClient = {
      translate: async (request) => {
        events.push('provider');
        requests.push(request);
        return job;
      },
    };

    const result = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      {
        env: { SONIOX_API_KEY: 'test-secret-key' },
        clientFactory: () => client,
      },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('00001: success');
    expect(requests).toHaveLength(1);
    expect(requests[0]?.model).toBe('stt-async-v5');
    expect(requests[0]?.client_reference_id).toBe('00001');
    expect(requests[0]?.from).toBe('zh');
    expect(requests[0]?.to).toBe('en');
    expect(requests[0]?.enable_speaker_diarization).toBe(true);
    expect(requests[0]?.context?.general).toEqual([
      { key: 'domain', value: 'Chinese Buddhist teaching' },
      { key: 'audience', value: 'Possible audience questions' },
    ]);
    expect(requests[0]?.wait).toBe(true);
    expect(requests[0]?.wait_options?.timeout_ms).toBe(30 * 60 * 1000);
    expect(requests[0]?.timeout_ms).toBe(30 * 60 * 1000);
    expect(requests[0]?.file).toEqual(audioBytes);
    expect(events).toEqual(['provider', 'cleanup']);

    const raw = JSON.parse(
      await readFile(join(outputRoot, '00001', 'raw.json'), 'utf8'),
    ) as {
      transcription: { client_reference_id?: string };
      transcript: { tokens: unknown[] };
    };
    const normalized = JSON.parse(
      await readFile(join(outputRoot, '00001', 'normalized.json'), 'utf8'),
    ) as NormalizedTranscript;
    const review = await readFile(
      join(outputRoot, '00001', 'review.md'),
      'utf8',
    );

    expect(raw.transcript.tokens).toHaveLength(2);
    expect(raw.transcription.client_reference_id).toBe('00001');
    assertNormalizedTranscript(normalized);
    expect(normalized.segments).toEqual([
      {
        start_ms: 1000,
        end_ms: 1500,
        speaker: '1',
        chinese: '你好。',
        english: 'Hello.',
        confidence: 0.9,
      },
      {
        start_ms: null,
        end_ms: null,
        speaker: '2',
        chinese: '谢谢。',
        english: 'Thank you.',
        confidence: 0.8,
      },
    ]);
    expect(review).toContain('[00:00:01.000 → 00:00:01.500] · Speaker 1');
    expect(review).toContain('[untimed] · Speaker 2');
    expect(review).toContain('**Chinese:** 你好。');
    expect(review).toContain('**English:** Thank you.');
    expect(new Uint8Array(await readFile(join(sampleRoot, 'audio.wav')))).toEqual(audioBytes);
  });
});

async function createSamples(root: string, sampleIds: string[]): Promise<void> {
  for (const sampleId of sampleIds) {
    const directory = join(root, sampleId);
    await mkdir(directory, { recursive: true });
    await writeFile(join(directory, 'audio.wav'), `audio-${sampleId}`);
    await writeFile(
      join(directory, 'metadata.json'),
      JSON.stringify({
        subtitle_id: sampleId,
        shoot_id: sampleId,
        source_url: `https://example.test/shoot/${sampleId}`,
        title: 'Test sample',
        date: '2024-01-01',
        mapping_status: 'exact_id_content_match',
        video_duration_seconds: 1,
        artifacts: { audio: 'audio.wav' },
        mapping_evidence: { rule: 'fixture content match', subtitle_topic: 'Test sample' },
        rejected_candidates: [],
      }),
    );
  }
}

function simpleJob(
  sampleId: string,
  events: string[],
  status: TranslationJob['status'] = 'completed',
  cleanupFailure = false,
): TranslationJob {
  const transcriptionId = `transcription-${sampleId}`;
  const fileId = `file-${sampleId}`;
  const token = {
    text: `中文${sampleId}`,
    start_ms: 100,
    end_ms: 900,
    confidence: 0.75,
    speaker: '1',
    language: 'zh',
    translation_status: 'original' as const,
  };
  return {
    id: transcriptionId,
    status,
    model: 'stt-async-v5',
    file_id: fileId,
    audio_duration_ms: 1000,
    transcript: { id: transcriptionId, text: token.text, tokens: [token] },
    translation: {
      mode: 'one_way',
      from: 'zh',
      to: 'en',
      duration_ms: 1000,
      original_text: token.text,
      translation_text: `English${sampleId}`,
      segments: [
        {
          from: 'zh',
          original_text: token.text,
          original_tokens: [token],
          to: 'en',
          translation_text: `English${sampleId}`,
        },
      ],
    },
    toJSON: () => ({
      id: transcriptionId,
      status,
      model: 'stt-async-v5',
      file_id: fileId,
      filename: 'audio.wav',
    }),
    destroy: async () => {
      events.push(`cleanup:${sampleId}`);
      if (cleanupFailure) throw new Error(`cleanup unavailable for ${sampleId}`);
    },
  };
}

function batchClient(
  events: string[],
  requests: TranslationRequest[],
  options: {
    failures?: Set<string>;
    timeoutIds?: Set<string>;
    invalidStatuses?: Set<string>;
    cleanupFailures?: Set<string>;
    delayMs?: number;
  } = {},
): TranslationClient & { maxInFlight: number } {
  let inFlight = 0;
  let maxInFlight = 0;
  return {
    get maxInFlight() {
      return maxInFlight;
    },
    translate: async (request) => {
      const sampleId = new TextDecoder().decode(request.file as Uint8Array).slice('audio-'.length);
      requests.push(request);
      events.push(`provider:${sampleId}`);
      inFlight += 1;
      maxInFlight = Math.max(maxInFlight, inFlight);
      try {
        await new Promise((resolve) => setTimeout(resolve, options.delayMs ?? 5));
        if (options.timeoutIds?.has(sampleId)) {
          throw new Error(`Transcription wait timed out after 1800000ms for ${sampleId}`);
        }
        if (options.failures?.has(sampleId)) {
          throw new Error(`provider failure for ${sampleId}`);
        }
        return simpleJob(
          sampleId,
          events,
          options.invalidStatuses?.has(sampleId) ? 'processing' : 'completed',
          options.cleanupFailures?.has(sampleId),
        );
      } finally {
        inFlight -= 1;
      }
    },
  };
}

describe('Soniox pilot validation and batch behavior', () => {
  test('rejects missing credentials, malformed IDs, and missing audio before requests', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    await createSamples(samplesRoot, ['00001']);
    const requests: TranslationRequest[] = [];
    const client = batchClient([], requests);
    const factory = () => client;

    const missingKey = await runCli(
      ['--samples-root', samplesRoot, '00001'],
      { env: {}, clientFactory: factory },
    );
    const malformed = await runCli(
      ['--samples-root', samplesRoot, '12'],
      { env: { SONIOX_API_KEY: 'secret' }, clientFactory: factory },
    );
    const missingAudio = await runCli(
      ['--samples-root', samplesRoot, '00002'],
      { env: { SONIOX_API_KEY: 'secret' }, clientFactory: factory },
    );

    expect(missingKey.exitCode).toBe(1);
    expect(missingKey.stderr).toContain('SONIOX_API_KEY is required');
    expect(malformed.exitCode).toBe(1);
    expect(malformed.stderr).toContain('exactly five digits');
    expect(missingAudio.exitCode).toBe(1);
    expect(missingAudio.stderr).toContain('missing audio artifact');
    expect(requests).toHaveLength(0);
  });

  test('requires the sample ID to match a positively verified mapping', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    await createSamples(samplesRoot, ['00001']);
    const metadataPath = join(samplesRoot, '00001', 'metadata.json');
    const validMetadata = JSON.parse(await readFile(metadataPath, 'utf8')) as Record<string, unknown>;
    const requests: TranslationRequest[] = [];
    const client = batchClient([], requests);
    const invalidMetadata: Record<string, unknown>[] = [
      { ...validMetadata, shoot_id: '99999' },
      { ...validMetadata, mapping_status: 'verified' },
      (() => {
        const metadata = { ...validMetadata };
        delete metadata.mapping_evidence;
        return metadata;
      })(),
    ];

    for (const metadata of invalidMetadata) {
      await writeFile(metadataPath, JSON.stringify(metadata));
      const result = await runCli(
        ['--samples-root', samplesRoot, '00001'],
        { env: { SONIOX_API_KEY: 'metadata-secret' }, clientFactory: () => client },
      );
      expect(result.exitCode).toBe(1);
      expect(result.stderr).toContain('unverified mapping metadata');
    }
    expect(requests).toHaveLength(0);
  });

  test('rejects output roots equal to or inside samples without modifying inputs', async () => {
    for (const outputSuffix of ['', 'generated']) {
      const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
      temporaryDirectories.push(root);
      const samplesRoot = join(root, 'samples');
      const sampleRoot = join(samplesRoot, '00001');
      await createSamples(samplesRoot, ['00001']);
      const audioBefore = await readFile(join(sampleRoot, 'audio.wav'));
      const metadataBefore = await readFile(join(sampleRoot, 'metadata.json'));
      const requests: TranslationRequest[] = [];
      let factoryCalls = 0;
      const outputRoot = outputSuffix ? join(samplesRoot, outputSuffix) : samplesRoot;

      const result = await runCli(
        ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
        {
          env: { SONIOX_API_KEY: 'path-secret' },
          clientFactory: () => {
            factoryCalls += 1;
            return batchClient([], requests);
          },
        },
      );

      expect(result.exitCode).toBe(1);
      expect(result.stderr).toContain('Output root must be outside samples root');
      expect(factoryCalls).toBe(0);
      expect(requests).toHaveLength(0);
      expect(await readFile(join(sampleRoot, 'audio.wav'))).toEqual(audioBefore);
      expect(await readFile(join(sampleRoot, 'metadata.json'))).toEqual(metadataBefore);
      expect(await readFile(join(sampleRoot, 'raw.json'), 'utf8').catch(() => '')).toBe('');
    }
  });

  test('rejects output roots symlinked into samples without modifying inputs', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputLink = join(root, 'output-link');
    const sampleRoot = join(samplesRoot, '00001');
    await createSamples(samplesRoot, ['00001']);
    await symlink(samplesRoot, outputLink, 'dir');
    const audioBefore = await readFile(join(sampleRoot, 'audio.wav'));

    const result = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputLink, '00001'],
      { env: { SONIOX_API_KEY: 'symlink-secret' }, clientFactory: () => batchClient([], []) },
    );

    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain('Output root must be outside samples root');
    expect(await readFile(join(sampleRoot, 'audio.wav'))).toEqual(audioBefore);
    expect(await readFile(join(sampleRoot, 'raw.json'), 'utf8').catch(() => '')).toBe('');
  });

  test('keeps missing original-token boundary timing null and fails without English text', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputRoot = join(root, 'soniox-runs');
    await createSamples(samplesRoot, ['00001']);
    const events: string[] = [];
    const requests: TranslationRequest[] = [];
    const client: TranslationClient = {
      translate: async () => {
        events.push('provider');
        const job = simpleJob('00001', events);
        const segment = job.translation?.segments[0];
        if (!segment) throw new Error('fixture segment missing');
        segment.original_tokens = [
          {
            text: '首',
            confidence: 0.8,
            speaker: '1',
            language: 'zh',
            translation_status: 'original',
          },
          {
            text: '尾',
            start_ms: 110,
            end_ms: 220,
            confidence: 0.9,
            speaker: '1',
            language: 'zh',
            translation_status: 'original',
          },
        ];
        for (const token of segment.original_tokens) Reflect.deleteProperty(token, 'confidence');
        return job;
      },
    };

    const timed = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      { env: { SONIOX_API_KEY: 'timing-secret' }, clientFactory: () => client },
    );
    const normalized = JSON.parse(
      await readFile(join(outputRoot, '00001', 'normalized.json'), 'utf8'),
    ) as NormalizedTranscript;
    expect(timed.exitCode).toBe(0);
    expect(normalized.segments[0]).toMatchObject({ start_ms: null, end_ms: 220, confidence: null });

    const missingEnglishClient: TranslationClient = {
      translate: async () => {
        events.push('provider-missing-english');
        const job = simpleJob('00001', events);
        const segment = job.translation?.segments[0];
        if (!segment) throw new Error('fixture segment missing');
        segment.translation_text = undefined;
        return job;
      },
    };
    const missingEnglish = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      { env: { SONIOX_API_KEY: 'english-secret' }, clientFactory: () => missingEnglishClient },
    );

    expect(missingEnglish.exitCode).toBe(1);
    expect(missingEnglish.stdout).toContain('translation_text is required');
    expect(events).toEqual(['provider', 'cleanup:00001', 'provider-missing-english']);
  });

  test('isolates provider failures, bounds concurrency at four, and returns a nonzero aggregate status', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputRoot = join(root, 'soniox-runs');
    const sampleIds = ['00001', '00002', '00003', '00004', '00005', '00006'];
    await createSamples(samplesRoot, sampleIds);
    const events: string[] = [];
    const requests: TranslationRequest[] = [];
    const client = batchClient(events, requests, {
      timeoutIds: new Set(['00003']),
      delayMs: 10,
    });

    const result = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, ...sampleIds],
      { env: { SONIOX_API_KEY: 'batch-secret' }, clientFactory: () => client },
    );

    expect(result.exitCode).toBe(1);
    expect(result.stdout).toContain('5 succeeded, 1 failed');
    expect(result.stdout).toContain('00003: failed — Transcription wait timed out after 1800000ms for 00003');
    for (const sampleId of sampleIds.filter((id) => id !== '00003')) {
      expect(result.stdout).toContain(`${sampleId}: success`);
      expect(await readFile(join(outputRoot, sampleId, 'normalized.json'), 'utf8')).toContain(sampleId);
    }
    expect(await readFile(join(outputRoot, '00003'), 'utf8').catch(() => '')).toBe('');
    expect(client.maxInFlight).toBeLessThanOrEqual(4);
    expect(requests).toHaveLength(sampleIds.length);
    expect(result.stdout).not.toContain('batch-secret');
  });

  test('retains local evidence and identifiers when remote cleanup fails', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputRoot = join(root, 'soniox-runs');
    await createSamples(samplesRoot, ['00001']);
    const events: string[] = [];
    const requests: TranslationRequest[] = [];
    const client = batchClient(events, requests, { cleanupFailures: new Set(['00001']) });

    const result = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      { env: { SONIOX_API_KEY: 'cleanup-secret' }, clientFactory: () => client },
    );

    expect(result.exitCode).toBe(1);
    expect(result.stdout).toContain('00001: failed');
    expect(result.stdout).toContain('remote resources: transcription=transcription-00001, file=file-00001');
    expect(result.stdout).toContain('cleanup remains for manual recovery');
    expect(await readFile(join(outputRoot, '00001', 'raw.json'), 'utf8')).toContain('transcription-00001');
    expect(await readFile(join(outputRoot, '00001', 'normalized.json'), 'utf8')).toContain('00001');
    expect(events).toEqual(['provider:00001', 'cleanup:00001']);
  });

  test('replaces a prior sample artifact directory without touching the supplied input', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputRoot = join(root, 'soniox-runs');
    await createSamples(samplesRoot, ['00001']);
    const events: string[] = [];
    const requests: TranslationRequest[] = [];
    const firstClient = batchClient(events, requests);
    const first = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      { env: { SONIOX_API_KEY: 'atomic-secret' }, clientFactory: () => firstClient },
    );
    await writeFile(join(outputRoot, '00001', 'stale.txt'), 'must be removed');
    const secondClient = batchClient(events, requests);
    const second = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      { env: { SONIOX_API_KEY: 'atomic-secret' }, clientFactory: () => secondClient },
    );

    expect(first.exitCode).toBe(0);
    expect(second.exitCode).toBe(0);
    expect(await readFile(join(outputRoot, '00001', 'stale.txt'), 'utf8').catch(() => '')).toBe('');
    expect(await readFile(join(outputRoot, '00001', 'normalized.json'), 'utf8')).toContain('00001');
    expect(new Uint8Array(await readFile(join(samplesRoot, '00001', 'audio.wav')))).toEqual(
      new TextEncoder().encode('audio-00001'),
    );
  });

  test('does not clean up a remote job when local persistence fails', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputRoot = join(root, 'soniox-runs');
    await createSamples(samplesRoot, ['00001']);
    await mkdir(outputRoot, { recursive: true });
    await writeFile(join(outputRoot, '.staging'), 'not a directory');
    const events: string[] = [];
    const requests: TranslationRequest[] = [];
    const client = batchClient(events, requests);

    const result = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      { env: { SONIOX_API_KEY: 'persistence-secret' }, clientFactory: () => client },
    );

    expect(result.exitCode).toBe(1);
    expect(result.stdout).toContain('00001: failed');
    expect(events).toEqual(['provider:00001']);
    expect(await readFile(join(outputRoot, '00001', 'raw.json'), 'utf8').catch(() => '')).toBe('');
    expect(result.stdout).not.toContain('persistence-secret');
  });

  test('does not publish invalid provider output or clean it up before persistence', async () => {
    const root = await mkdtemp(join(tmpdir(), 'soniox-pilot-'));
    temporaryDirectories.push(root);
    const samplesRoot = join(root, 'samples');
    const outputRoot = join(root, 'soniox-runs');
    await createSamples(samplesRoot, ['00001']);
    const events: string[] = [];
    const requests: TranslationRequest[] = [];
    const client = batchClient(events, requests, { invalidStatuses: new Set(['00001']) });

    const result = await runCli(
      ['--samples-root', samplesRoot, '--output-root', outputRoot, '00001'],
      { env: { SONIOX_API_KEY: 'invalid-secret' }, clientFactory: () => client },
    );

    expect(result.exitCode).toBe(1);
    expect(result.stdout).toContain('Invalid Soniox response');
    expect(events).toEqual(['provider:00001']);
    expect(await readFile(join(outputRoot, '00001', 'raw.json'), 'utf8').catch(() => '')).toBe('');
  });
});
