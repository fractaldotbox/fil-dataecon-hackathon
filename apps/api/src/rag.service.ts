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

jest.setTimeout(10 * 1000);
@Injectable()
export class RagService {
  getClient() {}

  // no effective way to search videos within a channel

  async loadIndex(params, limit: number = 100) {
    // table
  }
}
