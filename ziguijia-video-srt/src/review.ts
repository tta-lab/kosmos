import type { NormalizedTranscript, NormalizedSegment } from './schema';

function pad(value: number, width: number): string {
  return String(value).padStart(width, '0');
}

export function formatTimestamp(milliseconds: number): string {
  const hours = Math.floor(milliseconds / 3_600_000);
  const minutes = Math.floor((milliseconds % 3_600_000) / 60_000);
  const seconds = Math.floor((milliseconds % 60_000) / 1_000);
  const remainder = milliseconds % 1_000;
  return `${pad(hours, 2)}:${pad(minutes, 2)}:${pad(seconds, 2)}.${pad(remainder, 3)}`;
}

function formatTimeRange(segment: NormalizedSegment): string {
  if (segment.start_ms === null || segment.end_ms === null) return '[untimed]';
  return `[${formatTimestamp(segment.start_ms)} → ${formatTimestamp(segment.end_ms)}]`;
}

function formatSpeaker(speaker: string | null): string {
  if (speaker === null || speaker.length === 0) return 'Speaker ?';
  return /^speaker\s/i.test(speaker) ? speaker : `Speaker ${speaker}`;
}

export function renderReviewTranscript(transcript: NormalizedTranscript): string {
  const lines = [
    `# Soniox review transcript: ${transcript.sample_id}`,
    '',
    `- **Provider:** ${transcript.provider.name}`,
    `- **Region:** ${transcript.provider.region}`,
    `- **Model:** ${transcript.provider.model}`,
    `- **Translation:** ${transcript.translation.from ?? 'unknown'} → ${transcript.translation.to}`,
    '',
  ];

  transcript.segments.forEach((segment, index) => {
    lines.push(
      `## Segment ${index + 1} · ${formatTimeRange(segment)} · ${formatSpeaker(segment.speaker)}`,
      `- **Chinese:** ${segment.chinese}`,
      `- **English:** ${segment.english}`,
      `- **Confidence:** ${segment.confidence === null ? 'unavailable' : segment.confidence.toFixed(3)}`,
      '',
    );
  });

  return `${lines.join('\n').trimEnd()}\n`;
}
