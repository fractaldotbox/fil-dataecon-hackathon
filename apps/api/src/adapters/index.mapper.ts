import _ from 'lodash';

export const asContentKey = (indexKey: string, chunkStart: number) => {
  return [indexKey, chunkStart].join('_');
};

export const asDbParams = (
  indexKey: string,
  chunkStart: number,
  cid: string,
  clip: any,
) => {
  const contentKey = asContentKey(indexKey, chunkStart);
  const content = _.take(clip.map(({ text }) => text).join(' '), 1000);
  return [indexKey, cid, contentKey, content];
};

export const asIndex = (record) => {
  const { cid, content_key: contentKey, content } = record;

  return {
    id: cid + '-' + contentKey,
    content,
  };
};
