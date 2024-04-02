import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { YtService } from './yt.service';
import { CrawlService } from './crawl.service';
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [
        () => {
          return {
            lighthouse: {
              apiKey: process.env.LIGHTHOUSE_API_KEY,
            },
            indexer: {
              walletPrivateKey: process.env.INDEXER_WALLET_PRIVATE_KEY,
            },
            validator: {
              walletPrivateKey: process.env.INDEXER_WALLET_PRIVATE_KEY,
            },
          };
        },
      ],
    }),
  ],
  controllers: [AppController],
  providers: [AppService, CrawlService, YtService],
})
export class AppModule {}
