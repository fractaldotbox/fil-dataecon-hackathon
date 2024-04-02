import { Injectable } from '@nestjs/common';
import { HNSWLib } from '@langchain/community/vectorstores/hnswlib';
import { formatDocumentsAsString } from 'langchain/util/document';
import { PromptTemplate } from '@langchain/core/prompts';
import { ChatOpenAI, OpenAIEmbeddings } from '@langchain/openai';
import {
  RunnableSequence,
  RunnablePassthrough,
  RunnableLike,
} from '@langchain/core/runnables';
import { StringOutputParser } from '@langchain/core/output_parsers';
import { YoutubeTranscript } from 'youtube-transcript';

// import { HumanMessage, AIMessage } from "@langchain/core/messages";
// const { ChatOpenAI } = require("@langchain/openai");

// import { StringOutputParser } from "@langchain/core/output_parsers";
// import { ChatPromptTemplate } from "@langchain/core/prompts";
// import { ChatOpenAI } from "@langchain/openai";

export const DATA_BY_KEY = {
  ETH_4844: 'QX8qFzuGaEE',
};

@Injectable()
export class AppService {
  async getHello(): Promise<string> {
    const model = new ChatOpenAI({
      openAIApiKey: process.env.OPENAI_API_KEY!,
      // modelName: "gpt-4-1106-preview",
      // modelName: "gpt-4-0125-preview",

      modelName: 'gpt-3.5-turbo',
      // gpt-4-0125-preview
    });

    const transcript = await YoutubeTranscript.fetchTranscript(
      DATA_BY_KEY.ETH_4844,
    );
    console.log(transcript);

    // load common RAG database
    // RAG PULL

    //  TODO chroma based
    // transcript
    const vectorStore = await HNSWLib.fromTexts(
      transcript.map((item) => item.text),
      [{ id: 1 }],
      new OpenAIEmbeddings(),
    );

    const retriever = vectorStore.asRetriever();

    const prompt =
      PromptTemplate.fromTemplate(`Answer the question based only on the following context:
    {context}
    
    Question: {question}`);

    const chain = RunnableSequence.from([
      {
        context: retriever.pipe(formatDocumentsAsString),
        question: new RunnablePassthrough(),
      },
      prompt,
      model,
      new StringOutputParser(),
    ] as any);

    const response = await chain.invoke(
      'What is Simplifed Interactive Fraud Proof?',
    );

    return JSON.stringify(response, null, 4);

    // const prompt = ChatPromptTemplate.fromTemplate(
    //   `Answer the following question to the best of your ability:\n{question}`
    // );

    // const model = new ChatOpenAI({
    //   temperature: 0.8,
    // });

    // const outputParser = new StringOutputParser();

    // const chain = prompt.pipe(model).pipe(outputParser);

    // const stream = await chain.stream({
    //   question: "Why is the sky blue?",
    // });

    // for await (const chunk of stream) {
    //   console.log(chunk);
    // }
  }
}
