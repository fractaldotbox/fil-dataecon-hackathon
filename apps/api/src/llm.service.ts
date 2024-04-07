import { Injectable } from '@nestjs/common';
import { OpenAI } from 'openai';
import { formatDocumentsAsString } from 'langchain/util/document';
import { PromptTemplate } from '@langchain/core/prompts';
import { ChatOpenAI, OpenAIEmbeddings } from '@langchain/openai';
import { MistralAIEmbeddings } from '@langchain/mistralai';
// import { Chroma } from '@langchain/community/vectorstores/chroma';
import { HNSWLib } from '@langchain/community/vectorstores/hnswlib';
import {
  RunnableSequence,
  RunnablePassthrough,
  RunnableLike,
} from '@langchain/core/runnables';
import { StringOutputParser } from '@langchain/core/output_parsers';
// import { YoutubeTranscript } from 'youtube-transcript';
import { QueryDto } from './query.dto';
import { IndexService } from './index.service';

import { traceable } from 'langsmith/traceable';
import { wrapOpenAI } from 'langsmith/wrappers';

@Injectable()
export class LLMService {
  private model;
  private vectorStore;
  private openai;

  constructor(private readonly indexService: IndexService) {
    this.openai = wrapOpenAI(new OpenAI());

    this.vectorStore;
  }

  async refreshKb() {
    const indices = await this.indexService.loadIndex();

    console.log('indices size', indices.length)
    // console.log('load indices', indices.length);
    // rag pull the kb to in memory vector base
    this.vectorStore = await HNSWLib.fromTexts(
      indices.map(({ content }) => content),
      indices.map(({ id }) => {
        return {
          id,
        };
      }),
      // MistralAIEmbeddings()
      new OpenAIEmbeddings(),
    );
    console.log('refresh completed');
  }

  async query(queryDto: QueryDto): Promise<string> {
    // const transcript = await YoutubeTranscript.fetchTranscript(
    //   DATA_BY_KEY.ETH_4844,
    // );
    // console.log(transcript);

    // load common RAG database
    // RAG PULL
    await this.refreshKb();

    console.log('query', queryDto);
    console.log(this.vectorStore);

    const retriever = this.vectorStore.asRetriever();

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
      traceable(async (user_input) => {
        console.log('user_input', user_input);
        const result = await this.openai.chat.completions.create({
          messages: [{ role: 'user', content: user_input.value }],
          model: 'gpt-4',
        });

        return result.choices[0].message.content;
      }),
      new StringOutputParser(),
    ] as any);

    const response = await chain.invoke(queryDto);

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
