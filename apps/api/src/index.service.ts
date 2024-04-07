import _ from 'lodash';
import { Injectable } from '@nestjs/common';
import { AsrService } from './asr.service';
import { createLighthouseParams } from './adapters/lighthouse';
import { StorageService } from './storage.service';
import { ConfigService } from '@nestjs/config';
import { setTimeout } from 'timers/promises';
import { createSigner } from './adapters/tableland';
import { Database } from '@tableland/sdk';
import {
  bufferCount,
  filter,
  firstValueFrom,
  flatMap,
  from,
  map,
  mergeMap,
  tap,
  toArray,
} from 'rxjs';
import { YtService } from './yt.service';
import { asContentKey, asDbParams, asIndex } from './adapters/index.mapper';
import { asKey, asYoutubeUrl } from './adapters/youtube';

export type Input = {
  key: string;
  chunkStart: number;
  clip: any;
};
@Injectable()
export class IndexService {
  private walletPrivateKey;
  private db;
  private indexTableName;
  private timeIntervalS;
  constructor(
    private readonly asrService: AsrService,
    private readonly configService: ConfigService,
    private readonly ytService: YtService,
    private readonly storageService: StorageService,
  ) {
    this.walletPrivateKey = this.configService.get<string>(
      'indexer.walletPrivateKey',
    );
    this.indexTableName = this.configService.get<string>('db.indexTableName');

    this.timeIntervalS = this.configService.get<number>('video.timeIntervalS');

    const signer = createSigner(this.walletPrivateKey);
    this.db = new Database({ signer });
  }
  // use batch size of 3 now
  async writeIndices(inputs: Input[]) {
    const results = await firstValueFrom(
      from(inputs).pipe(
        mergeMap(async (input) => {
          const { key, chunkStart, clip } = input;
          console.log('clip', clip);

          // for now still write with default value for better timestamp seek

          if (!clip) {
            return {
              cid: 'dummy',
              chunkStart,
              clip: [
                // empty marker
                {
                  text: ' ',
                },
              ],
            };
          }
          const { cid } = await this.storageService.addFile(
            this.walletPrivateKey,
            JSON.stringify(clip),
          );

          console.log('created file', cid, clip.length);
          return {
            key,
            cid,
            chunkStart,
            clip,
          };
        }),
        filter((result) => !!result?.cid),
        toArray(),
      ),
    );

    console.log('results', results.length, results);

    if (!results.length) {
      return [];
    }
    // max 1024 length
    const insertIndexTemplate =
      'INSERT INTO ' +
      this.indexTableName +
      '(type, cid, content_key, content) VALUES (?, ?, ?, ?)';

    const allParams = results.map(({ cid, key, chunkStart, clip }) =>
      asDbParams(key, chunkStart, cid, clip),
    );

    const insertResults = await this.db.batch(
      allParams.map((params) =>
        this.db.prepare(insertIndexTemplate).bind(...params),
      ),
    );

    console.log(insertResults);
    return insertResults;
  }

  async mapIndexAsKb(indices) {
    return indices;
  }

  async loadIndex() {
    const { results } = await this.db
      .prepare(`SELECT * FROM ${this.indexTableName} limit 1000;`)
      .all();

    return results.filter(({ content }) => Boolean(content)).map(asIndex);
  }

  async loadIndexWithVideo(videoId: string, chunkStart: number) {
    const contentKey = asContentKey(asKey(videoId), chunkStart);
    const { results } = await this.db
      .prepare(`SELECT * FROM ${this.indexTableName} where content_key = ?;`)
      .bind(contentKey)
      .all();

    return results.filter(({ content }) => Boolean(content)).map(asIndex);
  }

  async indexVideo(videoId: string) {
    console.log('indexVideo', videoId, asYoutubeUrl(videoId));

    const key = asKey(videoId);
    const audioStream = await this.ytService.extractAudio(videoId);

    const transcript = await this.asrService.generateTranscript(audioStream);

    const { duration } = transcript;

    // write bigger chunks to be more effective
    const writeResults = await firstValueFrom(
      from(
        _.range(0, this.timeIntervalS, duration / this.timeIntervalS + 1),
      ).pipe(
        tap((chunkStart) => {
          console.log('write chunkStart', chunkStart, this.timeIntervalS);
        }),
        map((chunkStart) => {
          const clip = this.asrService.clip(
            transcript.segments,
            chunkStart,
            this.timeIntervalS,
          );

          console.log('clip', clip);

          return {
            key,
            chunkStart,
            clip,
          };
        }),
        bufferCount(10),
        mergeMap(async (chunks, i) => {
          // this part shd not //
          // error like nonce 34 already in mpool
          console.log('write chunks', i);

          const res = await setTimeout(10 * 1000, 'result');

          return await this.writeIndices(chunks);
        }, 1),
        toArray(),
      ),
    );

    console.log('write results', writeResults);

    return writeResults;
  }
}
