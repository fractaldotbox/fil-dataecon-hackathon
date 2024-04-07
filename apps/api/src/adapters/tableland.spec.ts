import { jest, describe, test, expect, beforeAll } from '@jest/globals';
import { signAuthMessage, uploadEncryptedFileWithText } from './lighthouse';
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';
import { createDbWithSigner, createSigner } from './tableland';
import { Database } from '@tableland/sdk';
import { Wallet } from 'ethers';

jest.setTimeout(15 * 60 * 1000);
const tableName = 'test_314159_832';
// refactor more generic

describe('tableland', () => {
  let db;

  beforeEach(() => {
    const signer = createSigner(process.env.INDEXER_WALLET_PRIVATE_KEY);

    db = createDbWithSigner(signer);

    // 0x4513e09002228b6F9bfac47CFaA0c58D5227a0a3
  });
  test.skip('create', async () => {
    const { meta: create } = await db
      .prepare(`CREATE TABLE test (id integer primary key, val text);`)
      .run();
    const results = await create.txn?.wait();
    console.log(results);
  });
  test('read', async () => {
    console.time('read');

    const { results } = await db.prepare(`SELECT * FROM ${tableName};`).all();
    console.log(results);
    console.timeEnd('read');
  });

  test('batch', async () => {
    const results = await db.batch([
      db.prepare(`INSERT INTO ${tableName}(id) VALUES (?1)`).bind(1),
      db.prepare(`INSERT INTO ${tableName}(id) VALUES (?1)`).bind(2),
      db.prepare(`INSERT INTO ${tableName}(id) VALUES (?1)`).bind(3),
    ]);
    expect(results[0].success).toEqual(true);
  });
});
