import _ from 'lodash';

export const asDbParams = (indexKey, chunkStart, cid, clip) => {
  const contentKey = [indexKey, chunkStart].join('_');

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
