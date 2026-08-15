import { randomUUID } from 'node:crypto';
import { mkdir, rename, rm, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import type { RawSonioxArtifact } from './normalize';
import type { NormalizedTranscript } from './schema';

export interface PersistedArtifacts {
  directory: string;
  raw: string;
  normalized: string;
  review: string;
}

async function writeJson(path: string, value: unknown): Promise<void> {
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function errorCode(error: unknown): string | undefined {
  return typeof error === 'object' && error !== null && 'code' in error && typeof error.code === 'string'
    ? error.code
    : undefined;
}

export async function persistSampleArtifacts(
  outputRoot: string,
  sampleId: string,
  raw: RawSonioxArtifact,
  normalized: NormalizedTranscript,
  review: string,
): Promise<PersistedArtifacts> {
  const root = resolve(outputRoot);
  const stagingRoot = join(root, '.staging');
  const target = join(root, sampleId);
  const staging = join(stagingRoot, `${sampleId}.${randomUUID()}`);
  const backup = join(stagingRoot, `${sampleId}.backup.${randomUUID()}`);

  await mkdir(staging, { recursive: true });
  let targetBackedUp = false;
  let targetInstalled = false;

  try {
    // Write the raw provider evidence first, then the derived artifacts, all
    // outside the published sample directory.
    await writeJson(join(staging, 'raw.json'), raw);
    await writeJson(join(staging, 'normalized.json'), normalized);
    await writeFile(join(staging, 'review.md'), review, 'utf8');

    try {
      await rename(target, backup);
      targetBackedUp = true;
    } catch (error) {
      if (errorCode(error) !== 'ENOENT') throw error;
    }

    try {
      await rename(staging, target);
      targetInstalled = true;
    } catch (error) {
      if (targetBackedUp) {
        await rename(backup, target);
        targetBackedUp = false;
      }
      throw error;
    }

    if (targetBackedUp) {
      // The published directory is complete at this point. A stale backup is
      // safer than reporting a failed run after successful installation.
      await rm(backup, { recursive: true, force: true }).catch(() => undefined);
      targetBackedUp = false;
    }

    return {
      directory: target,
      raw: join(target, 'raw.json'),
      normalized: join(target, 'normalized.json'),
      review: join(target, 'review.md'),
    };
  } catch (error) {
    if (!targetInstalled) {
      await rm(staging, { recursive: true, force: true });
      if (targetBackedUp) {
        await rename(backup, target).catch(() => undefined);
      }
    }
    throw error;
  }
}
