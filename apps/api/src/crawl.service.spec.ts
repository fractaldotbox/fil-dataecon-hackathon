import { Test, TestingModule } from '@nestjs/testing';
import { createDbWithSigner, createSigner } from './adapters/tableland';
import { CrawlService } from './crawl.service';
import { ConfigModule } from '@nestjs/config';
import config from './config';
import { YtService } from './yt.service';

jest.setTimeout(5 * 60 * 1000);
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
      providers: [YtService, CrawlService],
    }).compile();

    crawlService = app.get<CrawlService>(CrawlService);
  });
  it('create frontier table', async () => {
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

  it.only('seedFrontier', async () => {
    await crawlService.seedFrontier();
  });
});
