// borrowed from https://github.com/s2terminal/nlp-auto-eval-react/blob/main/lib/text.js

export const tokenizer = (text: string) => {
  return text.toLowerCase().split(' ');
};

export const nGram = (tokens: string[], n: number) => {
  const ret = [];
  for (let i = 0; i < tokens.length - (n - 1); i++) {
    const bag = [];
    for (let j = 0; j < n; j++) {
      bag.push(tokens[i + j]);
    }
    ret.push(bag);
  }
  return ret;
};

export const nGramPrecision = (
  hypothesis: string[],
  references: string[],
  n: number,
) => {
  const referenceNGram = nGram(references, n);
  return nGram(hypothesis, n).reduce((count, genBag) => {
    // 一致するのがあるかどうか
    const refIndex = referenceNGram.findIndex((refBag) => {
      return JSON.stringify(genBag) === JSON.stringify(refBag);
    });
    if (refIndex >= 0) {
      count += 1;
      // 一度使った要素は削除
      referenceNGram.splice(refIndex, 1);
    }
    return count;
  }, 0);
};

export const brevityPenalty = (hypLength: number, refLength: number) => {
  if (hypLength > refLength) {
    return 1;
  }
  return Math.exp(1 - refLength / hypLength);
};

type Precisions = { match: number; total: number }[];
export const bleuFromPrecisions = (
  precisions: Precisions,
  bp: number,
  n: number,
) => {
  const pn: number[] = Object.keys(precisions).map(
    (i) => precisions[Number(i)]!.match / precisions[Number(i)]!.total,
  );
  const product = pn.reduce((acc, p) => {
    // https://github.com/nltk/nltk/blob/3.2.5/nltk/translate/bleu_score.py#L487-L493
    if (p > 0) {
      // TODO: 警告を出す方が良い
      acc *= p;
    }
    return acc;
  }, 1);

  return bp * product ** (1 / n);
};

/**
 * @param n number
 * @returns [1,2,3,...,n]
 */
export const range = (n: number) => {
  return Array.from({ length: n }, (_v, k) => k + 1);
};

export const nGramPrecisions = (
  bleuN: number,
  tokensHyp: string[],
  tokensRef: string[],
): Precisions => {
  const ret: Precisions = [];
  for (let index = 1; index <= bleuN; index++) {
    ret[index] = {
      match: nGramPrecision(tokensHyp, tokensRef, index),
      total: tokensHyp.length - (index - 1),
    };
  }
  return ret;
};

export const bleu = (
  hypothesis: string[],
  references: string[],
  n: number = 4,
) => {
  const pn = nGramPrecisions(n, hypothesis, references);
  const bp = brevityPenalty(hypothesis.length, references.length);
  return bleuFromPrecisions(pn, bp, n);
};
