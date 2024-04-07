import { Injectable } from '@nestjs/common';
import { format } from 'path';
import { Client, MusicClient } from 'youtubei';

import { concat, firstValueFrom, from } from 'rxjs';
import { ConfigService } from '@nestjs/config';
@Injectable()
export class ValidatorService {
  constructor(private readonly configService: ConfigService) {}
}
