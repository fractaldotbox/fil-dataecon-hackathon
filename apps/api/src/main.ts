import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { CrawlService } from './crawl.service';


// crawlService.seedFrontier();

async function startValidatorActor() {
  const app = await NestFactory.create(AppModule);

  const crawlService = app.get<CrawlService>(CrawlService);

  // publish what is needed and status

  await app.listen(3003);
}

async function startIndexActor() {
  const app = await NestFactory.create(AppModule);

  const crawlService = app.get<CrawlService>(CrawlService);


  await app.listen(3002);
}

async function startChatActor() {
  const app = await NestFactory.create(AppModule);

  await app.listen(3001);
}

startValidatorActor();
startIndexActor();
startChatActor();
