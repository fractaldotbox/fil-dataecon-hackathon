import { timeInterval } from 'rxjs';

export default () => {
  return {
    openai: {
      apiKey: process.env.OPENAI_API_KEY,
    },
    lighthouse: {
      apiKey: process.env.LIGHTHOUSE_API_KEY,
    },
    db: {
      indexTablePrefix: 'rag',
      indexTableName: 'rag_314159_836',
      frontierTableName: 'frontier_314159_842',
    },
    video: {
      timeIntervalS: 30,
    },
    indexer: {
      concurrency: 3,
      walletPrivateKey: process.env.INDEXER_WALLET_PRIVATE_KEY,
    },
    validator: {
      scoreThresholdBleu: 0.6,
      walletPrivateKey: process.env.VALIDATOR_WALLET_PRIVATE_KEY,
    },
  };
};
