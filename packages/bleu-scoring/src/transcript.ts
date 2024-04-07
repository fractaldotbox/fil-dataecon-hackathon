import { tokenizer, bleu } from './text';
import { flow, get } from 'lodash/fp';

export type Segment = {
  start: number;
  end: number;
  text: string;
};

export type Timestamp = Pick<Segment, 'start' | 'end'>;

/**
 * Weights of timestamp vs text.
 */
export type TranscriptScoreWeights = [number, number];

/**
 * Weights of start/end time vs duration.
 */
export type TimestampScoreWeights = [number, number];

/**
 * @returns a score between 0 and 1.
 */
export function transcriptBleu(
  candidate: Segment,
  reference: Segment,
  transcripWeights: TranscriptScoreWeights = [0.1, 0.9],

  computeTimestampScore = buildTimestampScore([0.3, 0.7]),
): number {
  const tsScore = computeTimestampScore(reference, candidate);
  const textScore = computeTextBleu(reference, candidate);

  if (Math.round(transcripWeights[0] + transcripWeights[1]) !== 1) {
    throw new Error('total weights must equals 1');
  }

  return tsScore * transcripWeights[0] + textScore * transcripWeights[1];
}

export function buildTimestampScore(weights: TimestampScoreWeights) {
  return (candidate: Timestamp, reference: Timestamp) => {
    const start = similarityScore(candidate.start, reference.start);
    const end = similarityScore(candidate.end, reference.end);
    const duration = similarityScore(
      getDuration(candidate),
      getDuration(reference),
    );

    return ((start + end) / 2) * weights[0] + duration * weights[1];
  };
}

export function getDuration({ start, end }: Timestamp): number {
  return end - start;
}

export function similarityScore(n1: number, n2: number): number {
  const diff = Math.abs(n1 - n2);
  return Math.exp(-Math.pow(diff, 2));
}

// seperate punctuation marks from text
export function breakPunctuation(text: string): string {
  return text.replace(/(\w)([^\s\w])\s*/g, '$1 $2 ').trimRight();
}

export const toTextToken = flow(get('text'), breakPunctuation, tokenizer);

export function computeTextBleu(candidate: Segment, reference: Segment) {
  return bleu(toTextToken(candidate), toTextToken(reference), 4);
}
