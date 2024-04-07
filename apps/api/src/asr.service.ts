import _ from 'lodash';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createOpenAi } from './adapters/openai';
import { createReadStream, fstat, readFileSync } from 'fs';
import { join } from 'path';
import { Segment, joinText } from './domain/transcript';

@Injectable()
export class AsrService {
  private openai;

  constructor(private readonly configService: ConfigService) {
    const apiKey = configService.get('openai.apiKey');

    this.openai = createOpenAi(apiKey);
  }

  // https://archive.org/details/Greatest_Speeches_of_the_20th_Century/AddresstotheNationontheR.A.F.mp3

  async generateTranscript(audioStream) {
    console.log('Generating transcript');
    console.time('asr');
    const transcription = await this.openai.audio.transcriptions.create({
      file: audioStream,
      model: 'whisper-1',
      // prompt: '',
      // temperature: '0.1',
      // response_format: 'vtt',
      response_format: 'verbose_json',
      // use of word actually give much like sentence
      timestamp_granularities: 'word', // segment
      language: 'en', // this is optional but helps the model
    });
    console.timeEnd('asr');
    console.log('transcription', transcription);

    return transcription;
  }

  // asText(segments: any[]) {
  //   return segments.map(({ text }) => text).join(' ');
  // }

  stitch(segments: any[]): Segment {
    const firstSegment = _.first(segments);
    const lastSegment = _.last(segments);

    return {
      start: firstSegment.start,
      end: lastSegment.end,
      text: joinText(segments),
    };
  }

  clip(segments: any[], startTimeS: number, endTimeS: number) {
    // find segments that are within the time range

    // always use start to prevent completness
    return segments.filter((s) => s.start >= startTimeS && s.start <= endTimeS);
  }
  compare() {}
}
