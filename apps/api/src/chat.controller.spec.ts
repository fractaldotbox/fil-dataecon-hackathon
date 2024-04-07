import { Test, TestingModule } from '@nestjs/testing';
import { ChatController } from './chat.controller';
import { LLMService } from './llm.service';

describe('ChatController', () => {
  let chatController: ChatController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [ChatController],
      providers: [LLMService],
    }).compile();

    chatController = app.get<ChatController>(ChatController);
  });

  describe('root', () => {
    it('should answer query', () => {
      const queryDto = {
        query: 'What is the median price of a flat in Singapore',
      };
      expect(chatController.query(queryDto)).toBe('Hello World!');
    });
  });
});
