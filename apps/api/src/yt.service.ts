import { Injectable } from '@nestjs/common';
import { format } from 'path';
import { Client, MusicClient } from 'youtubei';

import { concat, firstValueFrom, from } from 'rxjs';

import {
  concatMap,
  map,
  mergeAll,
  mergeMap,
  tap,
  toArray,
} from 'rxjs/operators';

@Injectable()
export class YtService {
  getClient() {
    const youtube = new Client();

    return youtube;
  }

  // no effective way to search videos within a channel

  async paginateVideos(params, limit: number = 100) {
    const { fetchFx, getItems, getNext } = params;

    return await firstValueFrom(
      from(fetchFx()).pipe(
        concatMap((cursor) => {
          const pages = from(getNext(cursor)).pipe(
            mergeMap((results: any) => {
              return getItems(results) || [];
            }),
          );

          return concat(from(getItems(cursor)), pages);
        }),
        map((video: any) => {
          return video.id;
        }),
        toArray(),
      ),
    );
  }

  async load() {}
}
