import { _ } from 'lodash';
import { YoutubeTranscript } from 'youtube-transcript';
import { Injectable } from '@nestjs/common';
import { YtService } from './yt.service';
import {
  firstValueFrom,
  from,
  mergeAll,
  mergeMap,
  take,
  tap,
  toArray,
} from 'rxjs';
import { Playlist } from 'youtubei';
import { ConfigService } from '@nestjs/config';
import { createSigner } from './adapters/tableland';
import { Database } from '@tableland/sdk';
import { IndexService } from './index.service';
import { asYoutubeUrl } from './adapters/youtube';

const FRONTIER_SEED = [
  // {
  //   type: 'channel',
  //   channelId: 'UCygtiXCT3fs-aadgMINZ5xw',
  // },
  {
    type: 'search',
    keyword: 'Ang Mo Kio property',
  },
  {
    type: 'search',
    keyword: 'Tiong Bahru Apartment',
  },
  {
    type: 'playlist',
    playlistId: 'PLYIHyr0q2nW8W1Hr0PyMyztqYFt9ZoLbs',
  },
  {
    type: 'search',
    keyword: 'Singapore property',
  },
  {
    type: 'search',
    keyword: 'Singapore condo',
  },
  {
    type: 'search',
    keyword: 'HDB Flat',
  },
  {
    type: 'search',
    keyword: 'Singapore Real Estate',
  },
];

const CRAWL_TYPE_YOUTUBE = 'youtube';

@Injectable()
export class CrawlService {
  private frontier: any;
  private db: Database;
  private walletPrivateKey: string;
  private indexConcurrency: number;
  private frontierTableName;
  constructor(
    private readonly ytService: YtService,
    private readonly configService: ConfigService,
    private readonly indexService: IndexService,
  ) {
    this.frontier = new Set();

    this.frontierTableName = configService.get<string>('db.frontierTableName');
    this.indexConcurrency =
      configService.get<number>('indexer.concurrency') || 3;
    this.walletPrivateKey = this.configService.get<string>(
      'indexer.walletPrivateKey',
    );

    const signer = createSigner(this.walletPrivateKey);
    this.db = new Database({ signer });
  }

  createQuery(seed) {
    if (seed.type === 'playlist') {
      return {
        fetchFx: () => this.ytService.getClient().getPlaylist(seed.playlistId),
        getItems: (playlist) => playlist.videos?.items || [],
        getNext: (playlist) => playlist.videos.next(),
      };
    }

    return {
      fetchFx: () =>
        this.ytService.getClient().search(seed.keyword, {
          type: 'video',
        }),
      getItems: (cursor) => cursor.items || [],
      getNext: (cursor) => cursor.next(),
    };
  }

  async seedFrontier() {
    const queries = FRONTIER_SEED.map((seed) => this.createQuery(seed));
    const results = await firstValueFrom(
      from(queries).pipe(
        tap((query) => {
          console.log('process query', query);
        }),
        mergeMap((query) => this.ytService.paginateVideos(query)),
        // toArray()
        // tap((videoIds) => {
        //   videoIds.forEach((videoId: any) => {
        //     console.log('add video id', videoId);
        //     this.frontier.add(videoId);
        //   });
        // }),
        mergeAll(),
        toArray(),
      ),
    );

    // max 1024 length
    const insertFrontierTemplate =
      'INSERT INTO ' + this.frontierTableName + '(type, videoId) VALUES (?, ?)';

    const allParams = results.map((videoId) => {
      console.log(
        'insert frontier request videoId',
        videoId,
        asYoutubeUrl(videoId),
      );
      return [CRAWL_TYPE_YOUTUBE, videoId];
    });

    const insertResults = await this.db.batch(
      allParams.map((params) =>
        this.db.prepare(insertFrontierTemplate).bind(...params),
      ),
    );

    console.log('frontier # videos', this.frontier.size);
    console.log('insertResults', insertResults);
  }

  async loadFrontier() {
    const { results } = await this.db
      .prepare(`SELECT * FROM ${this.frontierTableName} order by id desc;`)
      .all();

    return results;
  }

  async crawl() {
    const requests = await this.loadFrontier();
    // TODO check status
    // TODO delay
    return firstValueFrom(
      from(requests.map(({ videoId }) => videoId as string)).pipe(
        mergeMap((videoId) => {
          return this.indexService.indexVideo(videoId);
        }, 3),
        take(10),
        toArray(),
      ),
    );
  }
}
