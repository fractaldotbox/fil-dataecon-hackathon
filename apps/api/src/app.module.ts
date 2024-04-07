import { Module } from '@nestjs/common';
import { ChatController } from './chat.controller';
import { LLMService } from './llm.service';
import { YtService } from './yt.service';
import { CrawlService } from './crawl.service';
import { ConfigModule } from '@nestjs/config';
import config from './config';
import { AsrService } from './asr.service';
import { IndexService } from './index.service';
import { StorageService } from './storage.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [config],
    }),
  ],
  controllers: [ChatController],
  providers: [
    StorageService,
    IndexService,
    AsrService,
    LLMService,
    CrawlService,
    YtService,
  ],
})
export class AppModule {}
