import _ from 'lodash';
import { Injectable } from '@nestjs/common';
import { AsrService } from './asr.service';
import { createLighthouseParams } from './adapters/lighthouse';
import { StorageService } from './storage.service';
import { ConfigService } from '@nestjs/config';
import { defineBlock } from 'viem';
import { createSigner } from './adapters/tableland';
import { Database } from '@tableland/sdk';
import {
  filter,
  firstValueFrom,
  flatMap,
  from,
  map,
  mergeMap,
  toArray,
} from 'rxjs';
import { YtService } from './yt.service';
import { asDbParams, asIndex } from './adapters/index.mapper';
import { asYoutubeUrl } from './adapters/youtube';
const TIME_INTERVAL = 30;

const INDEX_KEY = 'youtube';

export type Input = {
  chunkStart: number;
  clip: any;
};
@Injectable()
export class IndexService {
  private walletPrivateKey;
  private db;
  private indexTableName;
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

    const signer = createSigner(this.walletPrivateKey);
    this.db = new Database({ signer });
  }
  // use batch size of 3 now
  async writeIndices(inputs: Input[]) {
    const results = await firstValueFrom(
      from(inputs).pipe(
        mergeMap(async (input) => {
          const { chunkStart, clip } = input;

          console.log('clip', clip);
          if (!clip) {
            return null;
          }

          const { cid } = await this.storageService.addFile(
            this.walletPrivateKey,
            JSON.stringify(clip),
          );

          return {
            cid,
            chunkStart,
            clip,
          };
        }),
        filter(Boolean),
        toArray(),
      ),
    );

    // max 1024 length
    const insertIndexTemplate =
      'INSERT INTO ' +
      this.indexTableName +
      '(type, cid, content_key, content) VALUES (?, ?, ?, ?)';

    const allParams = results.map(({ cid, chunkStart, clip }) =>
      asDbParams(INDEX_KEY, chunkStart, cid, clip),
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
      .prepare(`SELECT * FROM ${this.indexTableName};`)
      .all();

    return results.filter(({ content }) => Boolean(content)).map(asIndex);
  }

  async loadIndexWithVideo(videoId: string) {
    const { results } = await this.db
      .prepare(`SELECT * FROM ${this.indexTableName} where key = '';`)
      .all();

    return results.filter(({ content }) => Boolean(content)).map(asIndex);
  }

  async indexVideo(videoId: string) {
    console.log('indexVideo', videoId, asYoutubeUrl(videoId));
    const audioStream = await this.ytService.extractAudio(videoId);

    const transcript = await this.asrService.generateTranscript(audioStream);

    const { duration } = transcript;

    // write bigger chunks to be more effective
    const writeResults = await firstValueFrom(
      from(_.range(0, TIME_INTERVAL, duration / TIME_INTERVAL + 1)).pipe(
        mergeMap((chunkStart) => {
          const clip = this.asrService.clip(
            transcript.segments,
            chunkStart,
            TIME_INTERVAL,
          );

          console.log('clip', clip);

          return this.writeIndices([chunkStart, clip]);
        }),
        toArray(),
      ),
    );

    console.log('write results', writeResults);

    return writeResults;
  }
}
