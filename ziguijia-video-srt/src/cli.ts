import { resolve } from 'node:path';
import { createSonioxClient, type TranslationClient } from './soniox-client';
import { runPilot, type PilotRunResult } from './pilot';

export type {
  TranslationClient,
  TranslationJob,
  TranslationRequest,
} from './soniox-client';

export interface CliDependencies {
  env?: Record<string, string | undefined>;
  clientFactory?: (apiKey: string) => TranslationClient;
}

export interface CliResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

interface ParsedArgs {
  help: boolean;
  sampleIds: string[];
  samplesRoot: string;
  outputRoot: string;
}

function usage(): string {
  return [
    'Usage: bun run src/cli.ts [options] <sample-id> [<sample-id> ...]',
    '',
    'Options:',
    '  --samples-root <path>  Verified sample root (default: samples)',
    '  --output-root <path>   Soniox artifact root (default: soniox-runs)',
    '  --help                 Show this help',
  ].join('\n');
}

function parseArgs(args: string[]): ParsedArgs {
  let samplesRoot = resolve('samples');
  let outputRoot = resolve('soniox-runs');
  const sampleIds: string[] = [];
  let help = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index]!;
    if (arg === '--help' || arg === '-h') {
      help = true;
      continue;
    }
    if (arg === '--') {
      sampleIds.push(...args.slice(index + 1));
      break;
    }
    if (arg === '--samples-root' || arg === '--output-root') {
      const value = args[index + 1];
      if (!value || value.startsWith('-')) throw new Error(`${arg} requires a path`);
      if (arg === '--samples-root') samplesRoot = resolve(value);
      else outputRoot = resolve(value);
      index += 1;
      continue;
    }
    if (arg.startsWith('--samples-root=')) {
      samplesRoot = resolve(arg.slice('--samples-root='.length));
      continue;
    }
    if (arg.startsWith('--output-root=')) {
      outputRoot = resolve(arg.slice('--output-root='.length));
      continue;
    }
    if (arg.startsWith('-')) throw new Error(`Unknown option: ${arg}`);
    sampleIds.push(arg);
  }

  return { help, sampleIds, samplesRoot, outputRoot };
}

function displayPath(path: string): string {
  const cwd = resolve('.');
  const relative = path.startsWith(`${cwd}/`) ? path.slice(cwd.length + 1) : path;
  return relative || '.';
}

function formatRun(result: PilotRunResult): string {
  const lines = [`Soniox pilot: ${result.succeeded} succeeded, ${result.failed} failed.`];
  for (const sample of result.samples) {
    if (sample.status === 'success') {
      lines.push(`${sample.sampleId}: success (${displayPath(sample.artifacts.directory)})`);
    } else {
      lines.push(`${sample.sampleId}: failed — ${sample.error}`);
      if (sample.artifacts) lines.push(`  local evidence: ${displayPath(sample.artifacts.directory)}`);
      const remote = sample.cleanup_pending ?? sample.remote;
      if (remote) {
        lines.push(`  remote resources: transcription=${remote.transcription_id ?? 'unknown'}, file=${remote.file_id ?? 'unknown'}`);
      }
      if (sample.cleanup_pending) {
        lines.push('  cleanup remains for manual recovery');
      }
    }
  }
  return `${lines.join('\n')}\n`;
}

export async function runCli(
  args: string[],
  dependencies: CliDependencies = {},
): Promise<CliResult> {
  let parsed: ParsedArgs;
  try {
    parsed = parseArgs(args);
  } catch (error) {
    return {
      exitCode: 1,
      stdout: '',
      stderr: `Usage error: ${error instanceof Error ? error.message : String(error)}\n${usage()}\n`,
    };
  }

  if (parsed.help) return { exitCode: 0, stdout: `${usage()}\n`, stderr: '' };

  const env = dependencies.env ?? process.env;
  const apiKey = env.SONIOX_API_KEY ?? '';
  try {
    if (apiKey.trim().length === 0) throw new Error('SONIOX_API_KEY is required');
    const result = await runPilot({
      sampleIds: parsed.sampleIds,
      samplesRoot: parsed.samplesRoot,
      outputRoot: parsed.outputRoot,
      apiKey,
      clientFactory: () => (dependencies.clientFactory ?? createSonioxClient)(apiKey),
    });
    return {
      exitCode: result.failed === 0 ? 0 : 1,
      stdout: formatRun(result),
      stderr: '',
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const safeMessage = apiKey.length > 0 ? message.split(apiKey).join('[redacted]') : message;
    return {
      exitCode: 1,
      stdout: '',
      stderr: `Preflight failed: ${safeMessage}\n`,
    };
  }
}

if (import.meta.main) {
  const result = await runCli(process.argv.slice(2));
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  process.exit(result.exitCode);
}
