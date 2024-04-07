import { Test, TestingModule } from '@nestjs/testing';
import { ValidatorService } from './validator.service';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { YtService } from './yt.service';
import { AsrService } from './asr.service';
import { fixture } from './asr.fixture';
import { IndexService } from './index.service';
import { StorageService } from './storage.service';
import config from './config';

jest.setTimeout(20 * 60 * 1000);
describe('ValidatorService', () => {
  let validatorService: ValidatorService;
  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          load: [config],
        }),
      ],
      controllers: [],
      providers: [
        IndexService,
        StorageService,
        ConfigService,
        YtService,
        AsrService,
        ValidatorService,
      ],
    }).compile();

    validatorService = app.get<ValidatorService>(ValidatorService);
  });

  test('#getSampleTimeRange', () => {
    const [start, end] = validatorService.getSampleTimeRange(300, 20);
    expect(start % 20).toEqual(0);
    expect(start >= 0).toEqual(true);
    expect(end <= 300).toEqual(true);
  });

  test('#validateClip', () => {
    const results = validatorService.validateClip(fixture, fixture, [30, 40]);

    const { score, isValid } = results;
    expect(isValid).toEqual(true);
    expect(score).toEqual(1);
  });
  test('#validate video', async () => {
    const videoId = 'be7L7nsY5Zc';
    // ensure this is ran
    // const indexResults = await indexService.indexVideo(videoId);
    const result = await validatorService.validate(videoId, 100);

    expect(result.isValid).toEqual(true);
  });
});
