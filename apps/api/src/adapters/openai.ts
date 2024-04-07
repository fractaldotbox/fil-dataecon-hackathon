import OpenAI from 'openai';

export const createOpenAi = (apiKey: string) => {
  return new OpenAI({
    apiKey,
  });
};
