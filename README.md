# DeRAG

### Project Overview

This project is a submission to the ["Filecoin IPC Data Economy Hackathon"](https://dorahacks.io/hackathon/filecoin-data-economy/onboarding)

Slides can be found at https://docs.google.com/presentation/d/1AVLqkqH05mcDIStsDQljMHI_xg8kGiZ06iIAb6t2Bsg/edit?usp=sharing

#### Demo

- https://www.loom.com/share/910016b14def41628351682c4efd785f
- You can run the model at localhost:3001 with LangSmith to investigate queries



### Archiecture

![alt text](image.png)

### Indexer
#### Crawler
- For youtube transcript crawling
  - We use a [Crawl Frontier](https://en.wikipedia.org/wiki/Crawl_frontier) design where videoids to crawl are seeded from queries of keywords / playlist ids
  ```
    {
      type: 'search',
      keyword: 'Ang Mo Kio property',
    }
  {
    type: 'playlist',
    playlistId: 'PLYIHyr0q2nW8W1Hr0PyMyztqYFt9ZoLbs',
  }
  ```
  - videoIds are written to DB Table on tableland
  - At `crawl()` it load latest videoIds for transcript processing.

#### Indexer
- ASR (Automatic Speech Recognition)
  - `whisper` from OpenAI for transcript and translation
- breakdown transcript into chunks and save as index for LLM usage



### LLM
- langchain / openAI for LLM
- langsmith for LLM observability

### Tehnology Usage in API

- Filecoin
  - (via lighthouse sdk)
   - for files upload
    - apps/api/src/adapters/lighthouse.ts
  - (via lighthouse contract) 
   - for PoDSI check
    - apps/contracts/src/DeRag.sol L34

  - Tableland
    - apps/api/src/adapters/tableland.ts
    - apps/api/src/crawl.service.ts L123 (insert table for crawl requests)
    - apps/api/src/index.service.ts L121 (read table for index cids)

- Nestjs
- for youtube
  - `youtubei` metadata loading
  - `youtube-transcript` for transcript (testing when whisper not in use)


### Techstack of validator
- We create Validator which verify indices created by indexer
- With Trustless Verification

#### Sample Check approach
- `validate()` at validator.service.ts compare
- BLEU score

#### ZKML approach
- We have added a python notebook to illustrate the process
  - ezkl / RNN network for zkML proof of prediction
  - https://github.com/pedialab/fil-dataecon-hackathon/blob/main/apps/ezkl/house_price_prediction.ipynb
  - model output [results.csv](apps/ezkl/results.csv) which can be used to convert into RAG index input
    - e.g. "Using rnn model on gov.sg data, price in Jurong East, 2 room unit is predicted to be $327k in 2024 Mar"


### Techstack of Smart Contract

- Foundry
- cd apps/contracts
- forge install
- forge build

- for test, specify calibration testnet rpc url explictly
  -  forge test --rpc-url https://calibration.filfox.info/rpc/v1 -vvv

### Building Env

- We use turborepo for monorepo cli
- it is recommend to pair with `env-cmd` to populate environment from `.env`
- values can be refer to `env.sample`

typical commands at

```
# start server
env-cmd pnpm dev
# eslint
env-cmd pnpm lint
# format(prettier)
env-cmd pnpm format
```

### Setup Whisper at local
- whisper
- https://github.com/openai/whisper

#### Testing


```
# unit test (.spec.ts) / integration test (.int.spec.ts)
env-cmd pnpm test

```