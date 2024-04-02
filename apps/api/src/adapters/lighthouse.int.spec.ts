import { jest, describe, test, expect, beforeAll } from '@jest/globals';
import {
    signAuthMessage, uploadEncryptedFileWithText,
} from './lighthouse';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';

//workaround
globalThis.crypto ??= require("node:crypto").webcrypto

jest.setTimeout(10 * 1000);

// refactor more generic
describe('with file encrypted', () => {


    test('uploadFile', async () => {
        const walletPrivateKey = generatePrivateKey()
        const account = privateKeyToAccount(walletPrivateKey) 

        const response = await uploadEncryptedFileWithText(
            'test',
            {
                lighthouseApiKey: process.env.LIGHTHOUSE_API_KEY,
                walletPublicKey: account.publicKey,
                walletPrivateKey
            }
        )
        
        expect(!!response.cid).toEqual(true)
    });

});
