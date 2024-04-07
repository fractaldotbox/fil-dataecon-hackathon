import { Test, TestingModule } from '@nestjs/testing';
import { LLMService } from './llm.service';
import { IndexService } from './index.service';
import { AsrService } from './asr.service';
import { ConfigModule } from '@nestjs/config';
import config from './config';
import { YtService } from './yt.service';
import { StorageService } from './storage.service';

describe('LLMService', () => {
  let llmService: LLMService;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          load: [config],
        }),
      ],
      controllers: [],
      providers: [
        AsrService,
        YtService,
        StorageService,
        IndexService,
        LLMService,
      ],
    }).compile();

    llmService = app.get<LLMService>(LLMService);
  });

  describe('root', () => {
    it.skip('#refreshKb', async () => {
      const results = await llmService.refreshKb();
      // Segmentation fault when run inside jest
    });
  });
});
