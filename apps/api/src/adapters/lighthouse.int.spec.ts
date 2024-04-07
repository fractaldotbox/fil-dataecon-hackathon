import { jest, describe, test, expect, beforeAll } from '@jest/globals';
import {
  createLighthouseParams,
  retrievePoDsi,
  signAuthMessage,
  uploadEncryptedFileWithText,
  uploadText,
} from './lighthouse';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';

//workaround
globalThis.crypto ??= require('node:crypto').webcrypto;

jest.setTimeout(10 * 1000);

// refactor more generic
describe('with file encrypted', () => {
  const walletPrivateKey = generatePrivateKey();
  test('uploadFile', async () => {
    const account = privateKeyToAccount(walletPrivateKey);
    const params = await createLighthouseParams({
      lighthouseApiKey: process.env.LIGHTHOUSE_API_KEY,
      walletPrivateKey,
    });
    const response = await uploadEncryptedFileWithText('test', ...params);

    expect(!!response.cid).toEqual(true);

    console.log('cid', cid);
  });

  const cid = 'QmS9ErDVxHXRNMJRJ5i3bp1zxCZzKP8QXXNH1yUR6dWeKZ';
  // from official example

  // const cid = 'QmYTaCnjNrrKCwXzC8ZLiiNJ78rsobXtfKwN8s9qCLBzVA';
  // testnet only && take a few minutes after upload & replication
  test.only('retrievePoDsi', async () => {
    const podsi = await retrievePoDsi(cid);
    expect(!!podsi.dealInfo).toEqual(true);
    // pieceCID vs cid
  });

  test('uploadText', async () => {
    const response = await uploadText('abcde', process.env.LIGHTHOUSE_API_KEY);
    console.log(response);
  });
});
