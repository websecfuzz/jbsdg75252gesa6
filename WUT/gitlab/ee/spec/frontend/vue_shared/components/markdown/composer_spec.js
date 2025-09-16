import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import createMockApollo from 'helpers/mock_apollo_helper';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ComposerComponent from 'ee/vue_shared/components/markdown/composer.vue';
import { updateText } from '~/lib/utils/text_markdown';
import eventHub from '~/vue_shared/components/markdown/eventhub';

jest.mock('~/lib/utils/text_markdown');

Vue.use(VueApollo);

describe('Markdown composer component', () => {
  let wrapper;
  let aiActionMutationHandler;
  let summarizeHandler;
  let composerHandler;

  const aiCompletionResponse = {
    id: 1,
    requestId: 1,
    content: 'AI generated content',
    contentHtml: 'AI generated content',
    errors: [],
    role: '',
    timestamp: '',
    type: '',
    chunkId: '',
    extras: {
      sources: [],
    },
    threadId: null,
  };
  const findPromptInput = () => wrapper.findByTestId('composer-user-prompt');
  const findComposerSubmitButton = () => wrapper.findByTestId('composer-submit');
  const findComposerInsertButton = () => wrapper.findByTestId('composer-insert');

  function createComponent(markdown = '') {
    aiActionMutationHandler = jest.fn().mockResolvedValue({ data: { aiAction: { errors: [] } } });
    const mockApollo = createMockApollo([[aiActionMutation, aiActionMutationHandler]]);
    mockApollo.defaultClient.setRequestHandler(
      aiResponseSubscription,
      ({ clientSubscriptionId }) => {
        if (clientSubscriptionId.startsWith('composer')) {
          composerHandler = createMockSubscription();
          return composerHandler;
        }
        summarizeHandler = createMockSubscription();
        return summarizeHandler;
      },
    );

    wrapper = mountExtended(ComposerComponent, {
      apolloProvider: mockApollo,
      propsData: { markdown },
      provide: { projectId: 1, sourceBranch: 'feature', targetBranch: 'main' },
    });
  }

  beforeEach(() => {
    window.gon = { current_user_id: '1' };
  });

  afterEach(() => {
    window.gon = {};
  });

  describe('composer AI feature', () => {
    it('renders prompt box when clicking write with Duo action button', async () => {
      createComponent();

      expect(findPromptInput().exists()).toBe(false);

      eventHub.$emit('SHOW_COMPOSER');

      await nextTick();

      expect(findPromptInput().exists()).toBe(true);
    });

    it('calls AI mutation when clicking composer item', async () => {
      createComponent();

      eventHub.$emit('SHOW_COMPOSER');

      await nextTick();

      findComposerSubmitButton().trigger('click');

      await nextTick();

      expect(aiActionMutationHandler).toHaveBeenCalledWith({
        input: {
          clientSubscriptionId: expect.anything(),
          descriptionComposer: {
            description: '<selected-text></selected-text>',
            resourceId: 'gid://gitlab/Project/1',
            sourceBranch: 'feature',
            sourceProjectId: 1,
            targetBranch: 'main',
            title: '',
            userPrompt: '',
            previousResponse: '',
          },
        },
      });
    });

    it('renders preview from AI response', async () => {
      createComponent();

      eventHub.$emit('SHOW_COMPOSER');

      await nextTick();

      composerHandler.next({
        data: {
          aiCompletionResponse,
        },
      });

      await nextTick();

      expect(wrapper.text()).toContain('AI generated content');
    });

    it('calls AI mutation with the previous response', async () => {
      createComponent();

      eventHub.$emit('SHOW_COMPOSER');

      composerHandler.next({
        data: {
          aiCompletionResponse,
        },
      });

      await nextTick();

      findComposerSubmitButton().trigger('click');

      await nextTick();

      expect(aiActionMutationHandler).toHaveBeenCalledWith({
        input: {
          clientSubscriptionId: expect.anything(),
          descriptionComposer: {
            description: '<selected-text></selected-text>',
            resourceId: 'gid://gitlab/Project/1',
            sourceBranch: 'feature',
            sourceProjectId: 1,
            targetBranch: 'main',
            title: '',
            userPrompt: '',
            previousResponse: 'AI generated content',
          },
        },
      });
    });

    it('inserts AI generated content into textarea when clicking insert button', async () => {
      createComponent();

      eventHub.$emit('SHOW_COMPOSER');

      await nextTick();

      composerHandler.next({
        data: {
          aiCompletionResponse,
        },
      });

      await nextTick();

      findComposerInsertButton().trigger('click');

      await nextTick();

      expect(updateText).toHaveBeenCalledWith({
        textArea: null,
        tag: 'AI generated content',
        cursorOffset: 0,
        wrap: false,
        replaceText: true,
      });
    });
  });
});
