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
    indexer: {
      walletPrivateKey: process.env.INDEXER_WALLET_PRIVATE_KEY,
    },
    validator: {
      walletPrivateKey: process.env.VALIDATOR_WALLET_PRIVATE_KEY,
    },
  };
};
