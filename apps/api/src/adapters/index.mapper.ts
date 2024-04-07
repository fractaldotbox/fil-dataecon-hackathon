import _ from 'lodash';
import { joinText } from '../domain/transcript';

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
  const content = _.truncate(joinText(clip), {
    length: 1000,
  });
  return ['video', contentKey, cid, content];
};

export const asIndex = (record) => {
  const { cid, content_key: contentKey, content } = record;

  return {
    id: cid + '-' + contentKey,
    cid,
    content,
  };
};
