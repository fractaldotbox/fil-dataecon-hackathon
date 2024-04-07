import { jest, describe, test, expect, beforeAll } from '@jest/globals';
import type { TranscriptScoreWeights } from './transcript';
import {
  transcriptBleu,
  breakPunctuation,
  similarityScore,
  buildTimestampScore,
} from './transcript';
import fc from 'fast-check';

describe('transcriptBleu()', () => {
  test('given weights [0, 1], it returns BLEU-4 score for the same timestamps', () => {
    const weights: TranscriptScoreWeights = [0, 1];

    const ref = {
      start: 0,
      end: 12.345,
      text: 'The NASA Opportunity rover is battling a massive dust storm on Mars.',
    };

    const can = {
      start: 0,
      end: 12.345,
      text: 'A NASA rover is fighting a massive storm on Mars.',
    };

    expect(transcriptBleu(ref, ref, weights)).toBe(1);
    expect(transcriptBleu(can, ref, weights)).toBeCloseTo(0.27);
  });

  test('given weights [1, 0], it returns score that represent similarity between the timestamps of the candidate and the reference', () => {
    const weights: TranscriptScoreWeights = [1, 0];

    const ref = {
      start: 0,
      end: 12.345,
      text: 'The NASA Opportunity rover is battling a massive dust storm on Mars.',
    };

    const can1 = {
      start: 0,
      end: 12.345,
      text: 'A NASA rover is fighting a massive storm on Mars.',
    };

    const can2 = {
      start: 2,
      end: 14.345,
      text: 'A NASA rover is fighting a massive storm on Mars.',
    };

    expect(transcriptBleu(ref, can1, weights)).toBe(1);
    expect(transcriptBleu(ref, can2, weights)).toBeCloseTo(0.705);
  });

  test('for the same text, the lower the timestamp weights the lower the total score', () => {
    const ref = {
      start: 0,
      end: 12.345,
      text: 'The NASA Opportunity rover is battling a massive dust storm on Mars.',
    };

    const can = {
      start: 1.0,
      end: 13.345,
      text: 'A NASA rover is fighting a massive storm on Mars.',
    };
    expect(transcriptBleu(can, ref, [0.1, 0.9])).toBeLessThan(
      transcriptBleu(can, ref, [0.2, 0.8]),
    );
  });

  test('for the same text, the closer the timestamp the higher the total score', () => {
    const ref = {
      start: 0,
      end: 12.345,
      text: 'The NASA Opportunity rover is battling a massive dust storm on Mars.',
    };

    const can1 = {
      start: 0.1,
      end: 12.445,
      text: 'A NASA rover is fighting a massive storm on Mars.',
    };

    const can2 = {
      ...can1,
      start: 1.0,
      end: 13.345,
    };

    expect(transcriptBleu(can2, ref)).toBeLessThan(transcriptBleu(can1, ref));
  });

  test('for the same text, the closer the timestamp duration the higher the total score', () => {
    const ref = {
      start: 5.0,
      end: 15.0,
      text: 'The NASA Opportunity rover is battling a massive dust storm on Mars.',
    };

    const can1 = {
      start: 4.0,
      end: 16.0,
      text: 'A NASA rover is fighting a massive storm on Mars.',
    };

    const can2 = {
      ...can1,
      start: 4.0,
      end: 17.0,
    };

    expect(transcriptBleu(can2, ref)).toBeLessThan(transcriptBleu(can1, ref));
  });

  test('it returns BLEU-4 score adjusted for timestamps', () => {
    const ref = {
      start: 0,
      end: 6.0,
      text: 'Let me ask you about you tweeting with no capitalization. Is the shift key broken on your keyboard?',
    };

    const can = {
      start: 0,
      end: 7.28000020980835,
      text: ' Let me ask you about you tweeting with no capitalization, does the shift key broken',
    };

    expect(transcriptBleu(can, ref)).toBeCloseTo(0.556);
  });
});

describe('breakPunctuation()', () => {
  describe('Properties', () => {
    it('should be idempotent', () => {
      fc.assert(
        fc.property(fc.asciiString(), (str) => {
          expect(breakPunctuation(breakPunctuation(str))).toEqual(
            breakPunctuation(str),
          );
        }),
      );
    });
  });

  test.each([
    ['Hello,world!', 'Hello , world !'],
    ["Hello,world!How's it going?", "Hello , world ! How ' s it going ?"],
  ])('should correctly separate punctuation from words', (input, expected) => {
    expect(breakPunctuation(input)).toEqual(expected);
  });
});

describe('similarityScore()', () => {
  const posFloat = fc.float({ min: 0, noDefaultInfinity: true, noNaN: true });

  describe('Properties', () => {
    it('should return 1 for identical numbers', () => {
      fc.assert(
        fc.property(posFloat, (num) => {
          expect(similarityScore(num, num)).toBe(1);
        }),
      );
    });

    it('should return a value between 0 and 1', () => {
      fc.assert(
        fc.property(posFloat, posFloat, (num1, num2) => {
          const score = similarityScore(num1, num2);
          expect(score).toBeGreaterThanOrEqual(0);
          expect(score).toBeLessThanOrEqual(1);
        }),
      );
    });

    it('should return a lower score for numbers that are further apart', () => {
      fc.assert(
        fc.property(posFloat, posFloat, (num1, num2) => {
          const score1 = similarityScore(num1, num1 + num2);
          const score2 = similarityScore(num1, num1 + num2 + 1);
          expect(score2).toBeLessThanOrEqual(score1);
        }),
      );
    });
  });
});

describe('computeTimestampScore()', () => {
  const posFloat = fc.float({ min: 0, noDefaultInfinity: true, noNaN: true });
  const computeTimestampScore = buildTimestampScore([0.3, 0.7]);

  describe('Properties', () => {
    it('should return 1 for identical timestamps', () => {
      fc.assert(
        fc.property(posFloat, posFloat, (start, diff) => {
          const ref = { start, end: start + diff };
          expect(computeTimestampScore(ref, ref)).toBe(1);
        }),
      );
    });

    it('should return a value between 0 and 1', () => {
      fc.assert(
        fc.property(
          posFloat,
          posFloat,
          posFloat,
          posFloat,
          (start1, diff1, start2, diff2) => {
            const ref = { start: start1, end: start1 + diff1 };
            const can = { start: start2, end: start2 + diff2 };
            const score = computeTimestampScore(can, ref);
            expect(score).toBeGreaterThanOrEqual(0);
            expect(score).toBeLessThanOrEqual(1);
          },
        ),
      );
    });

    it('should return a lower score for timestamps that are further apart', () => {
      fc.assert(
        fc.property(posFloat, posFloat, posFloat, (start, diff1, diff2) => {
          const ref = { start: start, end: start + diff1 };
          const can1 = { start: start, end: start + diff1 + diff2 };
          const can2 = { start: start, end: start + diff1 + diff2 + 1 };
          const score1 = computeTimestampScore(can1, ref);
          const score2 = computeTimestampScore(can2, ref);

          expect(score2).toBeLessThanOrEqual(score1);
        }),
      );
    });
  });
});
