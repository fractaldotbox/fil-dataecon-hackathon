import { Test, TestingModule } from '@nestjs/testing';
import { YtService } from './yt.service';

jest.setTimeout(10 * 1000);
describe('YtService', () => {
  let ytService: YtService;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [],
      providers: [YtService],
    }).compile();

    ytService = app.get<YtService>(YtService);
  });

  describe('root', () => {
    it('#loadAudio', async () => {
      const results = await ytService.loadAudio('QX8qFzuGaEE');
      expect(!!results).toBe(true);
    });
  });
});
