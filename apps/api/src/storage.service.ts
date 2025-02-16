import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createLighthouseParams,
  uploadEncryptedFileWithText,
  uploadText,
} from './adapters/lighthouse';
import got from 'got';

@Injectable()
export class StorageService {
  private apiKey: string;
  constructor(private readonly configSerivce: ConfigService) {
    this.apiKey = this.configSerivce.get('lighthouse.apiKey');
  }

  async addFile(walletPrivateKey: string, content: string) {
    return await uploadText(content, this.apiKey);

    // const params = await createLighthouseParams({
    //   lighthouseApiKey: this.apiKey,
    //   walletPrivateKey,
    // });

    // return await uploadEncryptedFileWithText(content, ...params);
  }
}
