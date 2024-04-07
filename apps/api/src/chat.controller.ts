import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { LLMService } from './llm.service';
import { YtService } from './yt.service';
import { QueryDto } from './query.dto';

@Controller()
export class ChatController {
  constructor(private readonly llmService: LLMService) {}

  // @Post()
  // async query(@Body() queryDto: QueryDto): Promise<string> {
  //   return this.llmService.query(queryDto);
  // }
  @Get()
  async query(@Query('q') queryDto): Promise<string> {
    return this.llmService.query(queryDto);
  }
  // debug
  @Get('refresh')
  async refresh() {
    await this.llmService.refreshKb();
  }
}
