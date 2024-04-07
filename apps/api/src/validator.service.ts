import _ from 'lodash';
import { Injectable } from '@nestjs/common';
import { format } from 'path';
import { Client, MusicClient } from 'youtubei';
import { concat, firstValueFrom, from, mergeMap } from 'rxjs';
import { ConfigService } from '@nestjs/config';
import { YtService } from './yt.service';
import { AsrService } from './asr.service';
import { transcriptBleu } from './domain/transcript';
import { IndexService } from './index.service';
import { getFile } from './adapters/lighthouse';
@Injectable()
export class ValidatorService {
  private scoreThreshold: number;
  private timeIntervalS: number;
  constructor(
    private readonly configService: ConfigService,
    private readonly ytService: YtService,
    private readonly asrService: AsrService,
    private readonly indexService: IndexService,
  ) {
    this.scoreThreshold = this.configService.get<number>(
      'validator.scoreThresholdBleu',
    );
    this.timeIntervalS = this.configService.get<number>('video.timeIntervalS');
  }

  getSampleTimeRange(videoDuration: number, interval: number) {
    const start =
      Math.floor(_.random(0, videoDuration - interval) / interval) * interval;
    return [start, start + interval];
  }

  validateClip(
    candidateTranscript: any,
    referenceTranscript: any,
    timeRange: number[],
  ) {
    const { segments, duration } = candidateTranscript;
    const [start, end] = timeRange;
    const candidateSegments = this.asrService.clip(segments, start, end);

    const referenceSegments = this.asrService.clip(
      referenceTranscript.segments,
      start,
      end,
    );

    console.log('candidateSegments', candidateSegments);

    console.log('referenceSegments', referenceSegments);

    const score = transcriptBleu(
      this.asrService.stitch(candidateSegments),
      this.asrService.stitch(referenceSegments),
    );

    return {
      isValid: score > this.scoreThreshold,
      score,
    };
  }

  async validate(videoId: string, interval: number) {
    const video = await this.ytService.extractPlatformMetadata(videoId);
    const videoDuration = video.duration || 60;

    const [start, end] = this.getSampleTimeRange(
      videoDuration,
      this.timeIntervalS,
    );

    console.log('load index', videoId, start);
    const audioStream = await this.ytService.extractAudio(videoId, start, end);

    const referenceTranscript =
      await this.asrService.generateTranscript(audioStream);

    const indices = await this.indexService.loadIndexWithVideo(videoId, start);

    console.log('indexResults', indices);

    const indicesWithClips = await firstValueFrom(
      from(indices).pipe(
        mergeMap(async (result: any) => {
          const { cid } = result;

          const clip = await getFile(cid).then((buffer) => {
            return JSON.parse(buffer.toString());
          });

          return {
            ...result,
            clip,
          };
        }),
      ),
    );

    console.log('indices clip', indicesWithClips);
    // candidateTranscript: any,

    const candidateTranscript = {
      segments: _.flatMap(indicesWithClips, ({ clip }) => clip),
    };
    return this.validateClip(candidateTranscript, referenceTranscript, [
      start,
      end,
    ]);
  }

  async generateSignature() {}
}
