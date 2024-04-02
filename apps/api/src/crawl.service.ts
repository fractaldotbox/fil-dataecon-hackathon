import { _ } from 'lodash';
import { YoutubeTranscript } from 'youtube-transcript';
import { Injectable } from '@nestjs/common';
import { YtService } from './yt.service';
import { firstValueFrom, from, mergeAll, mergeMap, tap, toArray } from 'rxjs';
import { Playlist } from 'youtubei';

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

  constructor(private readonly ytService: YtService) {
    this.frontier = new Set();

    this.seedFrontier();
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

    await firstValueFrom(
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
        tap((videoIds) => {
          videoIds.forEach((videoId: any) => {
            console.log('add video id', videoId);
            this.frontier.add(videoId);
          });
        }),
        mergeAll(),
        toArray(),
      ),
    );

    console.log('frontier # videos', this.frontier.size);
  }

  async index() {}
}
