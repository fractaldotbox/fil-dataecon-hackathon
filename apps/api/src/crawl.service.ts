import { _ } from 'lodash';
import { YoutubeTranscript } from 'youtube-transcript';
import { Injectable } from '@nestjs/common';
import { YtService } from './yt.service';
import { firstValueFrom, from, mergeAll, mergeMap, tap, toArray } from 'rxjs';
import { Playlist } from 'youtubei';
import { ConfigService } from '@nestjs/config';
import { createSigner } from './adapters/tableland';
import { Database } from '@tableland/sdk';
import { IndexService } from './index.service';

const FRONTIER_SEED = [
  {
    type: 'channel',
    channelId: 'UCygtiXCT3fs-aadgMINZ5xw',
  },
  {
    type: 'playlist',
    playlistId: 'PLYIHyr0q2nW8W1Hr0PyMyztqYFt9ZoLbs',
  },

  {
    type: 'search',
    channelId: 'UC_Lnb8ZHqqgLbp-7hltuT9w',
    keyword: 'property',
  },
];

@Injectable()
export class CrawlService {
  private frontier: any;
  private db: Database;
  private walletPrivateKey: string;
  private frontierTableName;
  constructor(
    private readonly ytService: YtService,
    private readonly configService: ConfigService,
    private readonly indexService: IndexService,
  ) {
    this.frontier = new Set();

    this.frontierTableName = configService.get<string>('db.frontierTableName');
    this.walletPrivateKey = this.configService.get<string>(
      'indexer.walletPrivateKey',
    );

    const signer = createSigner(this.walletPrivateKey);
    this.db = new Database({ signer });
  }

  async seedFrontier() {
    const queryVideosPlaylist = () =>
      this.ytService
        .getClient()
        .getPlaylist('PLYIHyr0q2nW8W1Hr0PyMyztqYFt9ZoLbs');

    const queryVideosSearch = () =>
      this.ytService.getClient().search('Singapore Property', {
        type: 'video',
      });

    const results = await firstValueFrom(
      from([
        {
          fetchFx: queryVideosPlaylist,
          getItems: (playlist) => playlist.videos?.items || [],
          getNext: (playlist) => playlist.videos.next(),
        },
        {
          fetchFx: queryVideosSearch,
          getItems: (cursor) => cursor.items || [],
          getNext: (cursor) => cursor.next(),
        },
      ]).pipe(
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
      console.log('videoId', videoId);
      return ['video', videoId];
    });

    const insertResults = await this.db.batch(
      allParams.map((params) =>
        this.db.prepare(insertFrontierTemplate).bind(...params),
      ),
    );

    console.log('frontier # videos', this.frontier.size);
    console.log('insertResults', insertResults);
  }

  async crawl() {
    const { results } = await this.db
      .prepare(`SELECT * FROM ${this.frontierTableName};`)
      .all();

    // TODO check status
    // TODO delay
    await firstValueFrom(
      from(results.map(({ videoId }) => videoId as string)).pipe(
        mergeMap((videoId) => {
          return this.indexService.indexVideo(videoId);
        }),
        toArray(),
      ),
    );
  }
}
