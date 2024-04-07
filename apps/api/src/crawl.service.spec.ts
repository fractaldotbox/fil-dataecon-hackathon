import { Test, TestingModule } from '@nestjs/testing';
import { createDbWithSigner, createSigner } from './adapters/tableland';
import { CrawlService } from './crawl.service';
import { ConfigModule } from '@nestjs/config';
import config from './config';
import { YtService } from './yt.service';
import { IndexService } from './index.service';
import { AsrService } from './asr.service';
import { StorageService } from './storage.service';

jest.setTimeout(20 * 60 * 1000);
describe('CrawlService', () => {
  let crawlService;
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
        AsrService,
        StorageService,
        YtService,
        CrawlService,
      ],
    }).compile();

    crawlService = app.get<CrawlService>(CrawlService);
  });
  it('#create frontier table', async () => {
    const signer = createSigner(process.env.INDEXER_WALLET_PRIVATE_KEY);

    const db = createDbWithSigner(signer);
    const { meta: create } = await db
      .prepare(
        `CREATE TABLE frontier (id integer primary key, type text, videoId text);`,
      )
      .run();
    const results = await create.txn?.wait();
    console.log('frontier', results);
  });

  it('#seedFrontier', async () => {
    await crawlService.seedFrontier();

    const results = await crawlService.loadFrontier();
    console.log('results', results);
  });

  it('#crawl', async () => {
    const results = await crawlService.crawl();
    console.log('results', results);
  });
});
