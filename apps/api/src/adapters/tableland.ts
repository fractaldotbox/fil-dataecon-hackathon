import { Database } from '@tableland/sdk';

import { Wallet, getDefaultProvider, ethers } from 'ethers';

const chain = 'filecoin-calibration';

// TODO viem signer
export const createSigner = (privateKey: string) => {
  // t410fiuj6beacekfw7g72yr6pvigfrvjcpifdqckql5y

  // To avoid connecting to  the browser wallet (locally, port 8545),
  // replace the URL with a provider like Alchemy, Infura, Etherscan, etc.
  const provider = new ethers.providers.JsonRpcProvider(
    'https://api.calibration.node.glif.io/rpc/v1',
  );
  const wallet = new Wallet(privateKey, provider);

  const signer = wallet.connect(provider);

  return signer;
};

// for RW
export const createDbWithSigner = (signer) => {
  // Connect to the database

  console.log('signer', signer.address);
  return new Database({ signer });
};

export const createTable = async (db: Database, prefix: string) => {
  const { meta: create } = await db
    .prepare(`CREATE TABLE ${prefix} (id integer primary key, val text);`)
    .run();

  return create.txn?.wait();
};

export const insert = async (db: Database, tableName: string) => {
  console.time('insert');
  // Insert a row into the table
  const { meta: insert } = await db
    .prepare(`INSERT INTO ${tableName} (id, val) VALUES (?, ?);`)
    .bind(0, 'Bobby Tables')
    .run();

  // Wait for transaction finality
  await insert.txn?.wait();

  console.timeEnd('insert');
  console.log('txn completed');

  const { results } = await db.prepare(`SELECT * FROM ${tableName};`).all();
  console.log(results);
};
