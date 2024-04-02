import lighthouse from '@lighthouse-web3/sdk';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class LighthouseService {
  private apiKey: string;

  constructor(private readonly configSerivce: ConfigService) {
    this.apiKey = this.configSerivce.get('LIGHTHOUSE_API_KEY');
  }

  async addFile(filePath) {
    // Upload File
    const uploadResponse = await lighthouse.upload(
      '/home/cosmos/Desktop/wow.jpg',
      'YOUR_API_KEY',
    );
  }
}
