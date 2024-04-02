import crypto from "crypto"
import lighthouse from '@lighthouse-web3/sdk';
import { Hex, createWalletClient, http } from 'viem';
import { privateKeyToAccount, signMessage } from 'viem/accounts';
import { filecoinCalibration, sepolia } from 'viem/chains';
import kavach from "@lighthouse-web3/kavach"


export const signAuthMessage = async (account:any) => {

  const client = createWalletClient({
    account,
    chain: sepolia,
    transport: http(),
  });

  
  const authMessage  = (await kavach.getAuthMessage(account.address))

  return client.signMessage({
    account,
    message: authMessage.message,
  });
};

export const uploadEncryptedFileWithText = async (
  text: string,
  options: any,
) => {
  const { lighthouseApiKey, walletPrivateKey } = options;
  const account = privateKeyToAccount(walletPrivateKey);

  const signedMessage = await signAuthMessage(
    account,
  );

  console.log('upload', account.address, signedMessage)
  const response = await lighthouse.textUploadEncrypted(
    text,
    lighthouseApiKey,
    account.address,
    signedMessage,
  );

  const { data } = response;

  return {
    name: data.Name,
    cid: data.Hash,
  };
};
