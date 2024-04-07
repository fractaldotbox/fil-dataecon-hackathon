import { Test, TestingModule } from '@nestjs/testing';
import { ChatController } from './chat.controller';

import { YtService } from './yt.service';
import { ConfigModule } from '@nestjs/config';
import config from './config';
import { IndexService } from './index.service';
import { AsrService } from './asr.service';
import { StorageService } from './storage.service';
import { fixture } from './asr.fixture';
import { createDbWithSigner, createSigner } from './adapters/tableland';

jest.setTimeout(30 * 60 * 1000);

describe('IndexService', () => {
  let indexService: IndexService;
  let asrService: AsrService;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          load: [config],
        }),
      ],
      controllers: [],
      providers: [YtService, AsrService, StorageService, IndexService],
    }).compile();

    asrService = app.get<AsrService>(AsrService);
    indexService = app.get<IndexService>(IndexService);
  });

  it.skip('create index table', async () => {
    const signer = createSigner(process.env.INDEXER_WALLET_PRIVATE_KEY);

    const db = createDbWithSigner(signer);
    const { meta: create } = await db
      .prepare(
        `CREATE TABLE rag (id integer primary key, type text, cid text, content_key text, content text);`,
      )
      .run();
    const results = await create.txn?.wait();
    console.log(results);
  });

  it('#indexVideo', async () => {
    const videoId = 'be7L7nsY5Zc';
    const indexResults = await indexService.indexVideo(videoId);

    expect(indexResults[0]?.success).toEqual(true);
  });

  it('#writeIndices', async () => {
    const segments1 = asrService.clip(fixture.segments, 3, 10);
    const segments2 = asrService.clip(fixture.segments, 11, 20);

    const indexResults = await indexService.writeIndices([
      {
        key: 'youtube-1',
        chunkStart: 3,
        clip: segments1,
      },
      {
        key: 'youtube-1',
        chunkStart: 11,
        clip: segments2,
      },
    ]);

    expect(indexResults[0].success).toEqual(true);
  });

  it('#loadIndex', async () => {
    const indexResults = await indexService.loadIndex();
    console.log('indexResults', indexResults);

    expect(!!indexResults[0]?.content).toEqual(true);
  });
  it('#loadIndexWithVideo', async () => {
    const indexResults = await indexService.loadIndexWithVideo(
      'be7L7nsY5Zc',
      30,
    );
    console.log('indexResults', indexResults);

    expect(!!indexResults[0]?.content).toEqual(true);
  });
});
