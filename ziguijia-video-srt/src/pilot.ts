import { readFile, realpath, stat } from 'node:fs/promises';
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import {
  PILOT_TIMEOUT_MS,
  SONIOX_CONTEXT,
  SONIOX_MODEL,
  type TranslationClient,
  type TranslationJob,
  type TranslationRequest,
} from './soniox-client';
import { buildRawSonioxArtifact, normalizeSonioxJob } from './normalize';
import { persistSampleArtifacts, type PersistedArtifacts } from './persistence';
import { renderReviewTranscript } from './review';
import { assertNormalizedTranscript } from './schema';

export const MAX_CONCURRENT_SAMPLES = 4 as const;

const VERIFIED_MAPPING_STATUSES = new Set([
  'exact_id_content_match',
  'user_confirmed_exact_id',
]);

export interface SampleInput {
  sampleId: string;
  audioPath: string;
}

export interface SampleSuccess {
  sampleId: string;
  status: 'success';
  artifacts: PersistedArtifacts;
}

export interface RemoteResources {
  transcription_id: string | null;
  file_id: string | null;
}

export interface SampleFailure {
  sampleId: string;
  status: 'failed';
  error: string;
  artifacts?: PersistedArtifacts;
  remote?: RemoteResources;
  cleanup_pending?: RemoteResources;
}

export type SampleOutcome = SampleSuccess | SampleFailure;

export interface PilotRunResult {
  samples: SampleOutcome[];
  succeeded: number;
  failed: number;
}

export interface PilotConfig {
  sampleIds: string[];
  samplesRoot: string;
  outputRoot: string;
  apiKey: string;
  clientFactory: () => TranslationClient;
}

function cleanMessage(error: unknown, secret: string): string {
  const message = error instanceof Error ? error.message : String(error);
  return secret.length > 0 ? message.split(secret).join('[redacted]') : message;
}

function inputError(message: string): never {
  throw new Error(message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function canonicalPath(path: string): Promise<string> {
  const missingTail: string[] = [];
  let current = resolve(path);
  while (true) {
    try {
      const existing = await realpath(current);
      return join(existing, ...missingTail.reverse());
    } catch (error) {
      if (!(typeof error === 'object' && error !== null && 'code' in error && error.code === 'ENOENT')) {
        throw error;
      }
      const parent = dirname(current);
      if (parent === current) return resolve(path);
      missingTail.push(basename(current));
      current = parent;
    }
  }
}

function isWithinPath(root: string, candidate: string): boolean {
  const relativePath = relative(root, candidate);
  return (
    relativePath === '' ||
    (relativePath !== '..' &&
      !relativePath.startsWith(`..${sep}`) &&
      !isAbsolute(relativePath))
  );
}

export async function validateOutputRoot(
  samplesRoot: string,
  outputRoot: string,
): Promise<void> {
  const requestedSamplesRoot = resolve(samplesRoot);
  const requestedOutputRoot = resolve(outputRoot);
  const [canonicalSamplesRoot, canonicalOutputRoot] = await Promise.all([
    canonicalPath(samplesRoot),
    canonicalPath(outputRoot),
  ]);
  if (
    isWithinPath(requestedSamplesRoot, requestedOutputRoot) ||
    isWithinPath(canonicalSamplesRoot, canonicalOutputRoot)
  ) {
    inputError(
      `Output root must be outside samples root: ${resolve(outputRoot)} is inside ${resolve(samplesRoot)}`,
    );
  }
}

export function validateSampleIds(sampleIds: string[]): void {
  if (sampleIds.length === 0) inputError('At least one five-digit sample ID is required');
  const seen = new Set<string>();
  for (const sampleId of sampleIds) {
    if (!/^\d{5}$/.test(sampleId)) {
      inputError(`Invalid sample ID: ${sampleId}; expected exactly five digits`);
    }
    if (seen.has(sampleId)) inputError(`Duplicate sample ID: ${sampleId}`);
    seen.add(sampleId);
  }
}

export async function resolveSampleInputs(
  sampleIds: string[],
  samplesRoot: string,
): Promise<SampleInput[]> {
  validateSampleIds(sampleIds);
  const root = resolve(samplesRoot);
  const inputs: SampleInput[] = [];
  for (const sampleId of sampleIds) {
    const audioPath = join(root, sampleId, 'audio.wav');
    let audioStat;
    try {
      audioStat = await stat(audioPath);
    } catch (error) {
      if (typeof error === 'object' && error !== null && 'code' in error && error.code === 'ENOENT') {
        inputError(`Sample ${sampleId} is missing audio artifact: ${audioPath}`);
      }
      throw error;
    }
    if (!audioStat.isFile()) inputError(`Sample ${sampleId} audio artifact is not a file: ${audioPath}`);

    const metadataPath = join(root, sampleId, 'metadata.json');
    let metadata: unknown;
    try {
      metadata = JSON.parse(await readFile(metadataPath, 'utf8')) as unknown;
    } catch (error) {
      if (typeof error === 'object' && error !== null && 'code' in error && error.code === 'ENOENT') {
        inputError(`Sample ${sampleId} is missing verification metadata: ${metadataPath}`);
      }
      inputError(`Sample ${sampleId} has invalid verification metadata: ${metadataPath}`);
    }
    const metadataRecord = isRecord(metadata) ? metadata : null;
    const mappingEvidence = metadataRecord?.mapping_evidence;
    if (
      metadataRecord === null ||
      metadataRecord.subtitle_id !== sampleId ||
      typeof metadataRecord.shoot_id !== 'string' ||
      metadataRecord.shoot_id !== sampleId ||
      typeof metadataRecord.mapping_status !== 'string' ||
      metadataRecord.mapping_status.length === 0 ||
      !VERIFIED_MAPPING_STATUSES.has(metadataRecord.mapping_status) ||
      !isRecord(mappingEvidence) ||
      typeof mappingEvidence.rule !== 'string' ||
      mappingEvidence.rule.length === 0 ||
      typeof mappingEvidence.subtitle_topic !== 'string' ||
      mappingEvidence.subtitle_topic.length === 0 ||
      !Array.isArray(metadataRecord.rejected_candidates)
    ) {
      inputError(`Sample ${sampleId} has unverified mapping metadata: ${metadataPath}`);
    }
    inputs.push({ sampleId, audioPath });
  }
  return inputs;
}

function remoteIds(job: TranslationJob | undefined): RemoteResources | undefined {
  if (!job) return undefined;
  return {
    transcription_id: typeof job.id === 'string' ? job.id : null,
    file_id: typeof job.file_id === 'string' ? job.file_id : null,
  };
}

function requestFor(sampleId: string, audio: Uint8Array): TranslationRequest {
  return {
    file: audio,
    filename: 'audio.wav',
    client_reference_id: sampleId,
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
}

async function processSample(
  input: SampleInput,
  config: PilotConfig,
  client: TranslationClient,
): Promise<SampleOutcome> {
  let job: TranslationJob | undefined;
  try {
    const audio = new Uint8Array(await readFile(input.audioPath));
    job = await client.translate(requestFor(input.sampleId, audio));
    const raw = buildRawSonioxArtifact(job);
    if (config.apiKey.length > 0 && JSON.stringify(raw).includes(config.apiKey)) {
      throw new Error('Provider response contained the API key; refusing to persist it');
    }
    const normalized = normalizeSonioxJob(input.sampleId, job);
    assertNormalizedTranscript(normalized);
    const review = renderReviewTranscript(normalized);
    const artifacts = await persistSampleArtifacts(
      config.outputRoot,
      input.sampleId,
      raw,
      normalized,
      review,
    );

    try {
      await job.destroy();
    } catch (error) {
      const remote = remoteIds(job)!;
      return {
        sampleId: input.sampleId,
        status: 'failed',
        error: `Remote cleanup failed: ${cleanMessage(error, config.apiKey)}`,
        artifacts,
        remote,
        cleanup_pending: remote,
      };
    }

    return { sampleId: input.sampleId, status: 'success', artifacts };
  } catch (error) {
    return {
      sampleId: input.sampleId,
      status: 'failed',
      error: cleanMessage(error, config.apiKey),
      remote: remoteIds(job),
    };
  }
}

async function mapWithConcurrency<T, R>(
  values: T[],
  concurrency: number,
  task: (value: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(values.length);
  let next = 0;
  async function worker(): Promise<void> {
    while (true) {
      const index = next++;
      if (index >= values.length) return;
      results[index] = await task(values[index]!);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, values.length) }, () => worker()),
  );
  return results;
}

export async function runPilot(config: PilotConfig): Promise<PilotRunResult> {
  if (config.apiKey.trim().length === 0) inputError('SONIOX_API_KEY is required');
  await validateOutputRoot(config.samplesRoot, config.outputRoot);
  const inputs = await resolveSampleInputs(config.sampleIds, config.samplesRoot);
  const client = config.clientFactory();
  const outcomes = await mapWithConcurrency(
    inputs,
    MAX_CONCURRENT_SAMPLES,
    (input) => processSample(input, config, client),
  );
  const succeeded = outcomes.filter((outcome) => outcome.status === 'success').length;
  return { samples: outcomes, succeeded, failed: outcomes.length - succeeded };
}
