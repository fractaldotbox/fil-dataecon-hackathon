import got from 'got';
import lighthouse from '@lighthouse-web3/sdk';
import { Hex, createWalletClient, http } from 'viem';
import { privateKeyToAccount, signMessage } from 'viem/accounts';
import { filecoinCalibration, sepolia } from 'viem/chains';
import kavach from '@lighthouse-web3/kavach';
import { writeFileSync } from 'fs';
// import { CID } from 'multiformats/cid'
import tmp from 'tmp';

// clien to cache
export const createLighthouseParams = async (
  options: any,
): Promise<[string, string, string]> => {
  const { lighthouseApiKey, walletPrivateKey } = options;
  const account = privateKeyToAccount(walletPrivateKey);

  const signedMessage = await signAuthMessage(account);
  return [lighthouseApiKey, account.address, signedMessage];
};

export const signAuthMessage = async (account: any) => {
  const client = createWalletClient({
    account,
    chain: sepolia,
    transport: http(),
  });

  const authMessage = await kavach.getAuthMessage(account.address);

  return client.signMessage({
    account,
    message: authMessage.message,
  });
};

export const retrievePoDsi = async (cid: string) => {
  // const results = await lighthouse.posdi(cid);
  // console.log('results', results);
  // return results?.data;

  let response = await got.get(
    'https://api.lighthouse.storage/api/lighthouse/get_proof',
    {
      searchParams: {
        cid,
        network: 'testnet', // Change the network to mainnet when ready
      },
    },
  );
  return JSON.parse(response.body);
};

// wokraorund seems .uploadText no deal params options

export const uploadText = async (text: string, apiKey: string) => {
  if (!text) {
    throw new Error('Empty text');
  }
  const dealParams = {
    num_copies: 2, // Number of backup copies
    repair_threshold: 28800, // When a storage sector is considered "broken"
    renew_threshold: 240, // When your storage deal should be renewed
    miner: ['t017840'], // Preferred miners
    network: 'calibration', // Network choice
    deal_duration: 1,
    add_mock_data: 2, // Mock data size in MB
  };
  const tmpobj = tmp.fileSync();

  console.log('text', text);
  writeFileSync(tmpobj.name, text);
  console.log('File: ', tmpobj.name);
  const response = await lighthouse.upload(
    tmpobj.name,
    apiKey,
    false,
    dealParams,
  );

  const { data } = response;
  console.log('uploadText', data);

  return {
    name: data.Name,
    cid: data.Hash,
  };
};

export const uploadEncryptedFileWithText = async (
  text: string,
  apiKey: string,
  publicKey: string,
  signedMessage: string,
) => {
  // const response = await lighthouse.textUploadEncrypted(
  //   text,
  //   apiKey,
  //   publicKey,
  //   signedMessage,
  // );

  const response = await lighthouse.textUploadEncrypted(
    text,
    apiKey,
    publicKey,
    signedMessage,
  );

  const { data } = response;

  return {
    name: data.Name,
    cid: data.Hash,
  };
};

export const getFile = async (cid: string) => {
  return got('https://gateway.lighthouse.storage/ipfs/' + cid).buffer();
};


// cannot find multiformats
// export const mapCidAsBytes = (cid:string)=>{
//   // https://github.com/filecoin-project/community/discussions/633

//   const v0 = CID.parse(cid)
//   return v0
// }
