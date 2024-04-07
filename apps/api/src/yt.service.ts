import { Injectable } from '@nestjs/common';
import { format } from 'path';
import { Client, MusicClient } from 'youtubei';

import { concat, firstValueFrom, from } from 'rxjs';

import * as youtubedl from 'youtube-dl-exec';

import {
  concatMap,
  map,
  mergeAll,
  mergeMap,
  tap,
  toArray,
} from 'rxjs/operators';
import got from 'got';
import { createReadStream, createWriteStream } from 'fs';
import stream from 'stream';
import { promisify } from 'util';
const pipeline = promisify(stream.pipeline);

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

  // https://github.com/yt-dlp/yt-dlp?tab=readme-ov-file#extract-audio
  async loadAudio(videoId: string) {
    const client = youtubedl.create(youtubedl['constants'].YOUTUBE_DL_PATH);
    return client('https://www.youtube.com/watch?v=' + videoId, {
      dumpSingleJson: true,
      noCheckCertificates: true,
      noWarnings: true,
      preferFreeFormats: true,
      audioFormat: 'mp3',
      extractAudio: true,
      addHeader: ['referer:youtube.com', 'user-agent:googlebot'],
    }).then(async (output: any) => {
      const url = output.url!;

      console.time('extract');
      const fileName = 'temp.mp3';
      await pipeline(got.stream(url), createWriteStream(fileName));
      console.timeEnd('extract');
      console.log('downloaded file', videoId, fileName);
      return createReadStream(fileName);
    });
  }
}
