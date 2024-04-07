import { jest, describe, test, expect, beforeAll } from '@jest/globals';
import {
  createLighthouseParams,
  getFile,
  retrievePoDsi,
  signAuthMessage,
  uploadEncryptedFileWithText,
  uploadText,
} from './lighthouse';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
import got from 'got';

//workaround
globalThis.crypto ??= require('node:crypto').webcrypto;

jest.setTimeout(60 * 1000);

// abcde
const cid = 'QmS9ErDVxHXRNMJRJ5i3bp1zxCZzKP8QXXNH1yUR6dWeKZ';

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

  // from official example

  // const cid = 'QmYTaCnjNrrKCwXzC8ZLiiNJ78rsobXtfKwN8s9qCLBzVA';
  // testnet only && take a few minutes after upload & replication
  test('#retrievePoDsi', async () => {
    const podsi = await retrievePoDsi(cid);
    console.log('podsi', JSON.stringify(podsi));
    // no pieceID
    // expect(podsi.dealInfo).toEqual(1);
    expect(!!podsi.dealInfo).toEqual(true);
    // pieceCID vs cid
  });

  test('#uploadText', async () => {
    const response = await uploadText('abcde', process.env.LIGHTHOUSE_API_KEY);
    console.log(response);
  });

  test('#getFile', async () => {
    const buffer = await getFile(cid);
    console.log('buffer', buffer.toString());
    expect(buffer.toString()).toEqual('abcde');
  });
});
