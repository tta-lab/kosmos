import { resolve } from 'node:path';
import type { SonioxTtsApi } from '@soniox/node';
import { createSonioxTts } from './soniox-client';

export interface TtsCliDependencies {
  env?: Record<string, string | undefined>;
  ttsFactory?: (apiKey: string) => SonioxTtsApi;
}

export interface TtsCliResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

interface ParsedArgs {
  help: boolean;
  text: string;
  outputPath: string;
  voice: string;
  language: string;
  format: string;
  speed: number | undefined;
}

export const DEFAULT_VOICE = 'Adrian';
export const DEFAULT_LANGUAGE = 'en';
export const DEFAULT_FORMAT = 'mp3';

const VALID_FORMATS = new Set([
  'wav',
  'mp3',
  'opus',
  'aac',
  'flac',
  'pcm_f32le',
  'pcm_s16le',
  'pcm_s16be',
  'pcm_mulaw',
  'pcm_alaw',
]);

function usage(): string {
  return [
    'Usage: bun run src/tts.ts [options] <text> <output-path>',
    '',
    'Synthesize speech with Soniox TTS and write the audio file.',
    '',
    'Options:',
    '  --voice <id>       Soniox voice identifier (default: Adrian)',
    '  --language <code>  ISO language code (default: en)',
    '  --format <fmt>     wav, mp3, opus, aac, flac, or pcm_* (default: mp3)',
    '  --speed <x>        Speaking rate 0.7-1.3 (default: 1.0)',
    '  --help             Show this help',
  ].join('\n');
}

function parseArgs(args: string[]): ParsedArgs {
  let voice = DEFAULT_VOICE;
  let language = DEFAULT_LANGUAGE;
  let format = DEFAULT_FORMAT;
  let speed: number | undefined;
  let help = false;
  const positionals: string[] = [];

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index]!;
    if (arg === '--help' || arg === '-h') {
      help = true;
      continue;
    }
    if (arg === '--voice' || arg === '--language' || arg === '--format' || arg === '--speed') {
      const value = args[index + 1];
      if (value === undefined || value.startsWith('-')) throw new Error(`${arg} requires a value`);
      if (arg === '--voice') voice = value;
      else if (arg === '--language') language = value;
      else if (arg === '--format') format = value;
      else speed = Number(value);
      index += 1;
      continue;
    }
    if (arg.startsWith('-')) throw new Error(`Unknown option: ${arg}`);
    positionals.push(arg);
  }

  if (positionals.length !== 2) {
    throw new Error(`expected exactly 2 positional arguments (<text> <output-path>), got ${positionals.length}`);
  }
  if (!VALID_FORMATS.has(format)) {
    throw new Error(`unsupported audio format: ${format} (supported: ${[...VALID_FORMATS].join(', ')})`);
  }
  if (speed !== undefined && (Number.isNaN(speed) || speed < 0.7 || speed > 1.3)) {
    throw new Error(`speed must be a number in 0.7-1.3, got ${String(speed)}`);
  }
  const [text, outputPath] = positionals;
  return { help, text, outputPath: resolve(outputPath), voice, language, format, speed };
}

function displayPath(path: string): string {
  const cwd = resolve('.');
  const relative = path.startsWith(`${cwd}/`) ? path.slice(cwd.length + 1) : path;
  return relative || '.';
}

export async function runTts(
  args: string[],
  dependencies: TtsCliDependencies = {},
): Promise<TtsCliResult> {
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
    const tts = (dependencies.ttsFactory ?? createSonioxTts)(apiKey);
    const options: {
      text: string;
      voice: string;
      language: string;
      audio_format: string;
      speed?: number;
    } = {
      text: parsed.text,
      voice: parsed.voice,
      language: parsed.language,
      audio_format: parsed.format,
    };
    if (parsed.speed !== undefined) options.speed = parsed.speed;

    const bytes = await tts.generateToFile(parsed.outputPath, options);
    return {
      exitCode: 0,
      stdout: `Wrote ${bytes} bytes to ${displayPath(parsed.outputPath)}\n`,
      stderr: '',
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const safeMessage = apiKey.length > 0 ? message.split(apiKey).join('[redacted]') : message;
    return {
      exitCode: 1,
      stdout: '',
      stderr: `TTS failed: ${safeMessage}\n`,
    };
  }
}

if (import.meta.main) {
  const result = await runTts(process.argv.slice(2));
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  process.exit(result.exitCode);
}
