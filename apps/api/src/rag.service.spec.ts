import { Test, TestingModule } from '@nestjs/testing';
import { RagService } from './rag.service';

describe('RagService', () => {
  let ragService: RagService;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [],
      providers: [RagService],
    }).compile();

    ragService = app.get<RagService>(RagService);
  });

  describe('root', () => {
    it('#refreshKb', () => {});
  });
});
