import { Injectable } from '@nestjs/common';
import { format } from 'path';
import { Client, MusicClient, Video } from 'youtubei';

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

import tmp from 'tmp';
import { asYoutubeUrl } from './adapters/youtube';

const pipeline = promisify(stream.pipeline);

@Injectable()
export class YtService {
  getClient() {
    const youtube = new Client();

    return youtube;
  }

  // possible to use getVideoTranscript to get official one, not to be mixed with asr generations
  // but facing this error
  // TypeError: Cannot read properties of undefined (reading 'transcriptBodyRenderer')

  async extractPlatformMetadata(videoId: string) {
    return (await this.getClient().getVideo(videoId)) as Video;
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
  async extractAudio(videoId: string, startS?: number, endS?: number) {
    const client = youtubedl.create(youtubedl['constants'].YOUTUBE_DL_PATH);

    // for partial extract no support by native ASR
    // --download-sections "*10:15-inf"';

    return client(asYoutubeUrl(videoId), {
      dumpSingleJson: true,
      noCheckCertificates: true,
      // noWarnings: true,
      verbose: true,
      preferFreeFormats: true,
      audioFormat: 'mp3',
      extractAudio: true,
      addHeader: ['referer:youtube.com', 'user-agent:googlebot'],
      'download-sections': '*01:30-01:35',
    } as any).then(async (output: any) => {
      const url = output.url!;
      console.time('extract');
      const tempFile = tmp.fileSync();
      const fileName = tempFile.name + '.mp3';
      await pipeline(got.stream(url), createWriteStream(fileName));
      console.timeEnd('extract');
      console.log('extract file', videoId, fileName);
      return createReadStream(fileName);
    });
  }
}
