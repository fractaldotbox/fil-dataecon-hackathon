# RAG PULL

### Project Overview

This project is a submission to the hackathon.

Slides can be found at <TODO>

#### Demo

- hosted at <TODO> by Vercel

### Archiecture

### Techstack in API

- lighthouse for files upload
- Nestjs
- for youtube
  - `youtubei` metadata loading
  - `youtube-transcript` for transcript (testing when whisper not in use)

### Techstack of ML

- `whisper` for transcript and translation

### Techstack of validator

- ezkl

### Techstack of Smart Contract

- Foundry

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

### Setup
- whisper
- https://github.com/openai/whisper

#### Testing


```
# unit test (.spec.ts) / integration test (.int.spec.ts)
env-cmd pnpm test

```