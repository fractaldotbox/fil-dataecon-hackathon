import { Test, TestingModule } from '@nestjs/testing';
import { YtService } from './yt.service';

jest.setTimeout(15 * 60 * 1000);
describe('YtService', () => {
  let ytService: YtService;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [],
      providers: [YtService],
    }).compile();

    ytService = app.get<YtService>(YtService);
  });

  it('#extractPlatformMetadata', async () => {
    const results = await ytService.extractPlatformMetadata('be7L7nsY5Zc');

    expect(results.duration > 0).toEqual(true);
  });
  it('#extractAudio all', async () => {
    const results = await ytService.extractAudio('be7L7nsY5Zc');
    expect(!!results).toBe(true);
  });
  it.only('#extractAudio partially', async () => {
    const results = await ytService.extractAudio('be7L7nsY5Zc', 30, 60);
    expect(!!results).toBe(true);
  });
});
