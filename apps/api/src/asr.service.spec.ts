import _ from 'lodash';
import { Test, TestingModule } from '@nestjs/testing';
import { ChatController } from './chat.controller';
import { AsrService } from './asr.service';
import { YtService } from './yt.service';
import { ConfigModule } from '@nestjs/config';
import config from './config';
import { createReadStream, fstat, readFileSync } from 'fs';
import { join } from 'path';
import { fixture } from './asr.fixture';

jest.setTimeout(30 * 60 * 1000);

describe('AsrService', () => {
  let asrService: AsrService;
  let ytService: YtService;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          load: [config],
        }),
      ],
      controllers: [],
      providers: [YtService, AsrService],
    }).compile();

    asrService = app.get<AsrService>(AsrService);
    ytService = app.get<YtService>(YtService);
  });

  it.skip('raw', async () => {
    const filePath = join(__dirname, '../../../sample1.mp3');
    console.log('filePath', filePath);

    const results = await asrService.generateTranscript(
      createReadStream(filePath),
    );
    expect(results).toContain('constitutional');
  });

  it('with audio', async () => {
    const audioStream = await ytService.loadAudio('be7L7nsY5Zc');
    // TODO add duration
    const results = await asrService.generateTranscript(audioStream);

    console.log('results.segment', results.segments);

    console.log(JSON.stringify(results, null, 4));
    expect(results.text).toContain('people');
  });

  it('#clip', () => {
    const results = asrService.clip(fixture.segments, 3, 35);
    expect(_.last(results).start < 35).toEqual(true);
  });

  // it.skip('should stream url but not working', async () => {
  //   // just 2 stages which is true for most workflow anyway
  //   const url =
  //     'https://ia903402.us.archive.org/6/items/Greatest_Speeches_of_the_20th_Century/AbdicationAddress_64kb.mp3';
  //   const audioStream = got.stream(url);
  //   const results = await asrService.generateTranscript(audioStream);
  // });
});
