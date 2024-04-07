import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createLighthouseParams,
  uploadEncryptedFileWithText,
  uploadText,
} from './adapters/lighthouse';

@Injectable()
export class StorageService {
  private apiKey: string;
  constructor(private readonly configSerivce: ConfigService) {
    this.apiKey = this.configSerivce.get('lighthouse.apiKey');
  }

  async addFile(walletPrivateKey: string, content: string) {
    const params = await createLighthouseParams({
      lighthouseApiKey: this.apiKey,
      walletPrivateKey,
    });

    return await uploadText(content, this.apiKey);

    // return await uploadEncryptedFileWithText(content, ...params);
  }
}
