import { readdir, readFile, stat } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import {
  assertNormalizedTranscript,
  type NormalizedTranscript,
} from './schema';

export interface ViewerConfig {
  samplesRoot?: string;
  runsRoot?: string;
  host?: string;
  port?: number;
}

export interface ViewerSampleSummary {
  id: string;
  title: string;
  date: string | null;
  video_duration_seconds: number | null;
  audio_duration_ms: number | null;
  segment_count: number;
  speakers: string[];
}

interface ViewerSample extends ViewerSampleSummary {
  transcript: NormalizedTranscript;
}

const DEFAULT_HOST = '127.0.0.1';
const DEFAULT_PORT = 4319;

const VIEWER_HTML = String.raw`<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#182420">
  <title>Soniox Field Notes</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #182420;
      --muted: #74827a;
      --paper: #f3efe5;
      --paper-strong: #fffdf7;
      --line: #d9d8cc;
      --moss: #6f9384;
      --moss-dark: #2f5c50;
      --coral: #ef7957;
      --gold: #d6a849;
      --shadow: 0 1.5rem 3rem rgb(24 36 32 / 10%);
    }

    * { box-sizing: border-box; }
    html { min-width: 20rem; background: var(--paper); }
    body {
      min-width: 20rem;
      min-height: 100dvh;
      margin: 0;
      background:
        radial-gradient(circle at 8% -8%, rgb(184 210 193 / 58%), transparent 30rem),
        radial-gradient(circle at 100% 12%, rgb(239 121 87 / 10%), transparent 27rem),
        var(--paper);
      color: var(--ink);
      font-family: "Avenir Next", "PingFang SC", "Hiragino Sans GB", sans-serif;
    }

    button, audio { font: inherit; }
    button { cursor: pointer; }
    .app { width: min(100% - 2rem, 92rem); margin: 0 auto; padding: 1.25rem 0 3rem; }
    .topbar { display: flex; align-items: flex-end; justify-content: space-between; gap: 2rem; margin-bottom: 1.35rem; }
    .kicker { margin: 0 0 .35rem; color: var(--coral); font-size: .7rem; font-weight: 800; letter-spacing: .16em; text-transform: uppercase; }
    h1, h2, p { margin-top: 0; }
    h1 { margin-bottom: .3rem; font-family: "Iowan Old Style", "Baskerville", Georgia, serif; font-size: clamp(2rem, 5vw, 4.2rem); font-weight: 500; letter-spacing: -.045em; line-height: .95; }
    .intro { max-width: 34rem; margin-bottom: 0; color: var(--muted); font-size: .92rem; line-height: 1.6; }
    .status { color: var(--muted); font-size: .8rem; }
    .sample-nav { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: .45rem; }
    .sample-button { border: 1px solid var(--line); border-radius: 999px; padding: .55rem .8rem; background: rgb(255 253 247 / 70%); color: var(--moss-dark); font-size: .74rem; font-weight: 800; letter-spacing: .04em; }
    .sample-button:hover, .sample-button:focus-visible { border-color: var(--moss); outline: none; }
    .sample-button.is-active { border-color: var(--ink); background: var(--ink); color: #fffdf7; }

    .workspace { display: grid; grid-template-columns: minmax(18rem, .72fr) minmax(0, 1.28fr); align-items: start; gap: 1rem; }
    .listening-desk { position: sticky; top: 1rem; overflow: hidden; border-radius: 1.35rem; padding: 1.25rem; background: var(--ink); color: #eef3ea; box-shadow: var(--shadow); }
    .listening-desk::before { content: ""; position: absolute; inset: 0 0 auto; height: .28rem; background: linear-gradient(90deg, var(--coral), var(--gold), var(--moss)); }
    .desk-label { margin-bottom: 2.1rem; color: #9fb8ab; font-size: .68rem; font-weight: 800; letter-spacing: .17em; text-transform: uppercase; }
    .sample-title { margin-bottom: .35rem; font-family: "Iowan Old Style", "Baskerville", Georgia, serif; font-size: clamp(1.8rem, 4vw, 3rem); font-weight: 500; letter-spacing: -.045em; line-height: 1; }
    .sample-date { margin-bottom: 1.6rem; color: #9fb8ab; font-size: .78rem; }
    audio { width: 100%; margin: .5rem 0 1rem; accent-color: var(--coral); }
    .transport { display: grid; grid-template-columns: 1fr 1fr; gap: .5rem; margin-bottom: 1.2rem; }
    .transport button { border: 1px solid rgb(255 255 255 / 20%); border-radius: .7rem; padding: .6rem; background: rgb(255 255 255 / 7%); color: #eef3ea; font-size: .75rem; font-weight: 800; }
    .transport button:hover, .transport button:focus-visible { border-color: var(--coral); outline: none; }
    .desk-stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem; margin-bottom: 1.15rem; }
    .stat { border-top: 1px solid rgb(255 255 255 / 18%); padding-top: .55rem; }
    .stat strong { display: block; color: #fffdf7; font-family: "Iowan Old Style", Georgia, serif; font-size: 1.5rem; font-weight: 500; }
    .stat span { color: #9fb8ab; font-size: .64rem; letter-spacing: .08em; text-transform: uppercase; }
    .desk-note { border-left: 2px solid var(--gold); margin: 0; padding-left: .7rem; color: #c7d5ca; font-size: .76rem; line-height: 1.55; }
    .now-playing { min-height: 2.2rem; margin: 1.1rem 0 0; color: #f4c6a9; font-size: .78rem; line-height: 1.45; }

    .transcript-panel { min-width: 0; border: 1px solid var(--line); border-radius: 1.35rem; background: rgb(255 253 247 / 82%); box-shadow: 0 .8rem 2.5rem rgb(24 36 32 / 5%); }
    .transcript-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; border-bottom: 1px solid var(--line); padding: 1.1rem 1.25rem; }
    .transcript-heading { margin: 0; font-family: "Iowan Old Style", "Baskerville", Georgia, serif; font-size: 1.35rem; font-weight: 500; }
    .active-readout { color: var(--moss-dark); font-size: .7rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
    .transcript { max-height: calc(100dvh - 8rem); overflow: auto; padding: .7rem; scrollbar-color: var(--moss) transparent; }
    .segment { position: relative; display: grid; grid-template-columns: 4.5rem minmax(0, 1fr); gap: .75rem; border: 1px solid transparent; border-radius: .85rem; padding: .85rem .7rem; transition: background .22s ease, border-color .22s ease, transform .22s ease; }
    .segment:hover { border-color: var(--line); background: #fff; }
    .segment.is-active { border-color: rgb(111 147 132 / 42%); background: #e7f0e8; transform: translateX(.18rem); }
    .segment-index { padding-top: .15rem; color: #a1aaa1; font-family: "Iowan Old Style", Georgia, serif; font-size: 1rem; }
    .segment-time { display: block; margin-top: .25rem; color: var(--muted); font-family: "SF Mono", "Roboto Mono", monospace; font-size: .58rem; line-height: 1.35; }
    .segment-content { min-width: 0; }
    .segment-meta { display: flex; align-items: center; flex-wrap: wrap; gap: .45rem; margin-bottom: .45rem; }
    .speaker-chip { display: inline-flex; align-items: center; border-radius: 999px; padding: .2rem .48rem; background: var(--ink); color: #fffdf7; font-size: .65rem; font-weight: 800; letter-spacing: .03em; }
    .speaker-chip.speaker-2 { background: var(--coral); }
    .confidence { color: var(--muted); font-family: "SF Mono", "Roboto Mono", monospace; font-size: .62rem; }
    .segment-text { margin: 0; }
    .segment-text.zh { color: var(--ink); font-size: 1rem; line-height: 1.65; }
    .segment-text.en { margin-top: .26rem; color: #66766e; font-size: .84rem; line-height: 1.55; }
    .empty { padding: 2rem; color: var(--muted); text-align: center; }

    @media (max-width: 760px) {
      .app { width: min(100% - 1rem, 48rem); padding-top: .8rem; }
      .topbar { display: block; }
      .sample-nav { justify-content: flex-start; margin-top: 1rem; }
      .workspace { grid-template-columns: 1fr; }
      .listening-desk { position: relative; top: 0; }
      .transcript { max-height: none; }
    }

    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after { scroll-behavior: auto !important; transition: none !important; }
    }
  </style>
</head>
<body>
  <div class="app">
    <header class="topbar">
      <div>
        <p class="kicker">Soniox field notes · local only</p>
        <h1>Listen / read / compare</h1>
        <p class="intro">Chinese speech, English translation, and Soniox's local speaker labels — aligned on one quiet workbench.</p>
      </div>
      <nav id="sample-nav" class="sample-nav" aria-label="Samples"></nav>
    </header>

    <main class="workspace">
      <section class="listening-desk" aria-label="Audio player">
        <div class="desk-label">Listening desk</div>
        <h2 id="sample-title" class="sample-title">Loading…</h2>
        <p id="sample-date" class="sample-date">Preparing local evidence</p>
        <audio id="audio" controls preload="metadata"></audio>
        <div class="transport">
          <button id="back-button" type="button">↶ 5 seconds</button>
          <button id="forward-button" type="button">5 seconds ↷</button>
        </div>
        <div id="desk-stats" class="desk-stats"></div>
        <p class="desk-note">Click any transcript block to jump the audio there. The active block follows playback.</p>
        <p id="now-playing" class="now-playing" aria-live="polite"></p>
      </section>

      <section class="transcript-panel" aria-label="Transcript">
        <header class="transcript-header">
          <h2 class="transcript-heading">Transcript / speaker map</h2>
          <span id="active-readout" class="active-readout">—</span>
        </header>
        <div id="transcript" class="transcript" aria-live="polite">
          <p class="empty">Loading transcript…</p>
        </div>
      </section>
    </main>
  </div>

  <script>
    const state = { samples: [], current: null, activeIndex: -1 };
    const audio = document.getElementById('audio');
    const sampleNav = document.getElementById('sample-nav');
    const transcript = document.getElementById('transcript');
    const title = document.getElementById('sample-title');
    const date = document.getElementById('sample-date');
    const stats = document.getElementById('desk-stats');
    const nowPlaying = document.getElementById('now-playing');
    const activeReadout = document.getElementById('active-readout');

    function formatTime(milliseconds) {
      if (milliseconds === null || milliseconds === undefined) return 'untimed';
      const total = Math.max(0, Math.round(milliseconds / 1000));
      const hours = Math.floor(total / 3600);
      const minutes = Math.floor((total % 3600) / 60);
      const seconds = total % 60;
      return [hours, minutes, seconds].map((part, index) => index === 0 ? String(part).padStart(2, '0') : String(part).padStart(2, '0')).join(':');
    }

    function formatDuration(milliseconds) {
      if (milliseconds === null || milliseconds === undefined) return '—';
      return formatTime(milliseconds);
    }

    function setText(element, value) {
      element.textContent = value;
    }

    function getSpeakerLabel(speaker) {
      return speaker ? 'Speaker ' + speaker : 'Speaker ?';
    }

    function renderSampleNav() {
      sampleNav.replaceChildren();
      state.samples.forEach((sample) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'sample-button' + (state.current && state.current.id === sample.id ? ' is-active' : '');
        button.textContent = sample.id;
        button.title = sample.title;
        button.addEventListener('click', () => loadSample(sample.id));
        sampleNav.append(button);
      });
    }

    function renderStats(sample) {
      const segments = sample.transcript.segments;
      const speakers = [...new Set(segments.map((segment) => segment.speaker || '?'))];
      const cells = [
        ['Segments', String(segments.length)],
        ['Speakers', String(speakers.length)],
        ['Duration', formatDuration(sample.transcript.audio_duration_ms)]
      ];
      stats.replaceChildren();
      cells.forEach(([label, value]) => {
        const cell = document.createElement('div');
        cell.className = 'stat';
        const strong = document.createElement('strong');
        strong.textContent = value;
        const span = document.createElement('span');
        span.textContent = label;
        cell.append(strong, span);
        stats.append(cell);
      });
    }

    function renderTranscript(sample) {
      transcript.replaceChildren();
      sample.transcript.segments.forEach((segment, index) => {
        const block = document.createElement('article');
        block.className = 'segment';
        block.dataset.index = String(index);
        block.tabIndex = 0;
        block.setAttribute('aria-label', getSpeakerLabel(segment.speaker) + ', segment ' + (index + 1));

        const indexColumn = document.createElement('div');
        indexColumn.className = 'segment-index';
        indexColumn.textContent = String(index + 1).padStart(2, '0');
        const time = document.createElement('span');
        time.className = 'segment-time';
        time.textContent = formatTime(segment.start_ms);
        indexColumn.append(time);

        const content = document.createElement('div');
        content.className = 'segment-content';
        const meta = document.createElement('div');
        meta.className = 'segment-meta';
        const speaker = document.createElement('span');
        speaker.className = 'speaker-chip' + (segment.speaker === '2' ? ' speaker-2' : '');
        speaker.textContent = getSpeakerLabel(segment.speaker);
        const confidence = document.createElement('span');
        confidence.className = 'confidence';
        confidence.textContent = segment.confidence === null ? 'confidence —' : 'confidence ' + segment.confidence.toFixed(3);
        meta.append(speaker, confidence);

        const chinese = document.createElement('p');
        chinese.className = 'segment-text zh';
        chinese.textContent = segment.chinese;
        const english = document.createElement('p');
        english.className = 'segment-text en';
        english.textContent = segment.english;
        content.append(meta, chinese, english);
        block.append(indexColumn, content);

        const jump = () => {
          if (segment.start_ms !== null) {
            audio.currentTime = segment.start_ms / 1000;
            setActive(index, true);
          }
        };
        block.addEventListener('click', jump);
        block.addEventListener('keydown', (event) => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            jump();
          }
        });
        transcript.append(block);
      });
      state.activeIndex = -1;
      setText(activeReadout, 'ready');
    }

    function setActive(index, shouldScroll) {
      if (index < 0) return;
      const blocks = transcript.querySelectorAll('.segment');
      blocks.forEach((block, blockIndex) => block.classList.toggle('is-active', blockIndex === index));
      if (state.activeIndex !== index) {
        state.activeIndex = index;
        const segment = state.current.transcript.segments[index];
        setText(activeReadout, 'segment ' + String(index + 1).padStart(2, '0') + ' · ' + getSpeakerLabel(segment.speaker));
        setText(nowPlaying, segment.chinese + ' / ' + segment.english);
        if (shouldScroll) blocks[index].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      }
    }

    function syncTranscript() {
      if (!state.current) return;
      const time = audio.currentTime * 1000;
      let candidate = -1;
      state.current.transcript.segments.forEach((segment, index) => {
        if (segment.start_ms !== null && time >= segment.start_ms) candidate = index;
        if (segment.start_ms !== null && time >= segment.start_ms && (segment.end_ms === null || time <= segment.end_ms)) candidate = index;
      });
      setActive(candidate, false);
    }

    async function loadSample(id) {
      setText(title, 'Loading…');
      setText(date, 'Reading local evidence');
      setText(nowPlaying, '');
      transcript.innerHTML = '<p class="empty">Loading transcript…</p>';
      const response = await fetch('/api/samples/' + id);
      if (!response.ok) throw new Error('Unable to load sample ' + id);
      state.current = await response.json();
      setText(title, state.current.title);
      setText(date, state.current.date || 'verified sample ' + state.current.id);
      audio.src = '/api/samples/' + id + '/audio';
      audio.load();
      renderStats(state.current);
      renderTranscript(state.current);
      renderSampleNav();
      history.replaceState(null, '', '?sample=' + id);
    }

    async function boot() {
      const response = await fetch('/api/samples');
      if (!response.ok) throw new Error('Unable to load samples');
      state.samples = await response.json();
      renderSampleNav();
      const requested = new URLSearchParams(location.search).get('sample');
      const first = state.samples.find((sample) => sample.id === requested) || state.samples[0];
      if (!first) throw new Error('No normalized samples found in soniox-runs');
      await loadSample(first.id);
    }

    audio.addEventListener('timeupdate', syncTranscript);
    audio.addEventListener('loadedmetadata', syncTranscript);
    document.getElementById('back-button').addEventListener('click', () => { audio.currentTime = Math.max(0, audio.currentTime - 5); });
    document.getElementById('forward-button').addEventListener('click', () => { audio.currentTime = Math.min(audio.duration || Infinity, audio.currentTime + 5); });
    boot().catch((error) => {
      setText(title, 'Viewer unavailable');
      setText(date, error instanceof Error ? error.message : String(error));
      transcript.innerHTML = '<p class="empty">Check that the Soniox pilot artifacts exist, then reload.</p>';
    });
  </script>
</body>
</html>`;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function roots(config: ViewerConfig): { samplesRoot: string; runsRoot: string } {
  return {
    samplesRoot: resolve(config.samplesRoot ?? 'samples'),
    runsRoot: resolve(config.runsRoot ?? 'soniox-runs'),
  };
}

async function sampleIds(runsRoot: string): Promise<string[]> {
  const entries = await readdir(runsRoot, { withFileTypes: true }).catch(() => []);
  return entries
    .filter((entry) => entry.isDirectory() && /^\d{5}$/u.test(entry.name))
    .map((entry) => entry.name)
    .sort();
}

async function metadataFor(samplesRoot: string, id: string): Promise<{
  title: string;
  date: string | null;
  video_duration_seconds: number | null;
}> {
  try {
    const value = JSON.parse(await readFile(join(samplesRoot, id, 'metadata.json'), 'utf8')) as unknown;
    if (!isRecord(value)) throw new Error('metadata is not an object');
    return {
      title: typeof value.title === 'string' && value.title.length > 0 ? value.title : `Sample ${id}`,
      date: typeof value.date === 'string' ? value.date : null,
      video_duration_seconds: typeof value.video_duration_seconds === 'number' ? value.video_duration_seconds : null,
    };
  } catch {
    return { title: `Sample ${id}`, date: null, video_duration_seconds: null };
  }
}

async function loadSample(config: ViewerConfig, id: string): Promise<ViewerSample> {
  if (!/^\d{5}$/u.test(id)) throw new Error('Invalid sample ID');
  const { samplesRoot, runsRoot } = roots(config);
  const transcript = JSON.parse(await readFile(join(runsRoot, id, 'normalized.json'), 'utf8')) as unknown;
  assertNormalizedTranscript(transcript);
  if (transcript.sample_id !== id) throw new Error('Normalized sample ID does not match path');
  const metadata = await metadataFor(samplesRoot, id);
  return {
    id,
    ...metadata,
    audio_duration_ms: transcript.audio_duration_ms,
    segment_count: transcript.segments.length,
    speakers: [...new Set(transcript.segments.map((segment) => segment.speaker ?? '?'))],
    transcript,
  };
}

async function loadSummaries(config: ViewerConfig): Promise<ViewerSampleSummary[]> {
  const { runsRoot } = roots(config);
  const ids = await sampleIds(runsRoot);
  const samples = await Promise.all(ids.map((id) => loadSample(config, id)));
  return samples.map(({ transcript, ...summary }) => summary);
}

function json(value: unknown, status = 200): Response {
  return Response.json(value, {
    status,
    headers: { 'cache-control': 'no-store' },
  });
}

function notFound(): Response {
  return json({ error: 'Not found' }, 404);
}

async function serveAudio(request: Request, path: string): Promise<Response> {
  const fileStat = await stat(path).catch(() => null);
  if (!fileStat?.isFile()) return notFound();
  const size = fileStat.size;
  const file = Bun.file(path);
  const headers = {
    'accept-ranges': 'bytes',
    'cache-control': 'no-store',
    'content-type': 'audio/wav',
  };
  const range = request.headers.get('range');
  if (!range) {
    return new Response(request.method === 'HEAD' ? null : file, {
      headers: { ...headers, 'content-length': String(size) },
    });
  }
  const match = /^bytes=(\d*)-(\d*)$/u.exec(range);
  if (!match) return new Response(null, { status: 416, headers: { 'content-range': `bytes */${size}` } });
  let start = match[1] ? Number(match[1]) : Math.max(0, size - Number(match[2]));
  let end = match[2] && match[1] ? Number(match[2]) : size - 1;
  if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0 || end < start || start >= size) {
    return new Response(null, { status: 416, headers: { 'content-range': `bytes */${size}` } });
  }
  end = Math.min(end, size - 1);
  return new Response(request.method === 'HEAD' ? null : file.slice(start, end + 1), {
    status: 206,
    headers: {
      ...headers,
      'content-length': String(end - start + 1),
      'content-range': `bytes ${start}-${end}/${size}`,
    },
  });
}

export function createViewerFetch(config: ViewerConfig = {}) {
  return async (request: Request): Promise<Response> => {
    const url = new URL(request.url);
    if (url.pathname === '/' && request.method === 'GET') {
      return new Response(VIEWER_HTML, { headers: { 'content-type': 'text/html; charset=utf-8' } });
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') return json({ error: 'Method not allowed' }, 405);
    if (url.pathname === '/api/samples') {
      return json(await loadSummaries(config));
    }
    const audioMatch = /^\/api\/samples\/(\d{5})\/audio$/u.exec(url.pathname);
    if (audioMatch) {
      const { samplesRoot } = roots(config);
      return serveAudio(request, join(samplesRoot, audioMatch[1]!, 'audio.wav'));
    }
    const sampleMatch = /^\/api\/samples\/(\d{5})$/u.exec(url.pathname);
    if (sampleMatch) {
      try {
        return json(await loadSample(config, sampleMatch[1]!));
      } catch (error) {
        return json({ error: error instanceof Error ? error.message : 'Unable to load sample' }, 404);
      }
    }
    return notFound();
  };
}

export function startViewerServer(config: ViewerConfig = {}) {
  const host = config.host ?? process.env.VIEWER_HOST ?? DEFAULT_HOST;
  const port = config.port ?? Number(process.env.PORT ?? DEFAULT_PORT);
  const server = Bun.serve({
    hostname: host,
    port,
    fetch: createViewerFetch(config),
  });
  return server;
}

if (import.meta.main) {
  const server = startViewerServer();
  console.log(`Soniox viewer: ${server.url}`);
  process.on('SIGINT', () => {
    server.stop();
    process.exit(0);
  });
}
