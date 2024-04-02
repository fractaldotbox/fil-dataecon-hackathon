import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { CrawlService } from './crawl.service';

async function startValidatorActor() {
  const app = await NestFactory.create(AppModule);

  const crawlService = app.get<CrawlService>(CrawlService);

  crawlService.seedFrontier();

  // publish what is needed and status

  await app.listen(3001);
}

async function startIndexActor() {
  const app = await NestFactory.create(AppModule);

  const crawlService = app.get<CrawlService>(CrawlService);

  crawlService.seedFrontier();

  await app.listen(3002);
}

async function startChatActor() {
  const app = await NestFactory.create(AppModule);

  const crawlService = app.get<CrawlService>(CrawlService);

  crawlService.seedFrontier();

  await app.listen(3003);
}
startValidatorActor();
startIndexActor();
startChatActor();
