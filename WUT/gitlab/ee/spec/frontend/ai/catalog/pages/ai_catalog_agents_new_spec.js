import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import createAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import AiCatalogAgentsNew from 'ee/ai/catalog/pages/ai_catalog_agents_new.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import {
  mockAgentProject,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('AiCatalogAgentsNew', () => {
  let wrapper;
  let createAiCatalogAgentMock;

  const createComponent = () => {
    createAiCatalogAgentMock = jest.fn().mockResolvedValue(mockCreateAiCatalogAgentSuccessMutation);
    const apolloProvider = createMockApollo([[createAiCatalogAgent, createAiCatalogAgentMock]]);

    wrapper = shallowMountExtended(AiCatalogAgentsNew, {
      apolloProvider,
    });
  };

  const findForm = () => wrapper.findComponent(AiCatalogAgentForm);

  afterEach(() => {
    createAlert.mockClear();
    jest.clearAllMocks();
  });

  describe('Form Submit', () => {
    let mockModalShow;

    const { name, description, project } = mockAgentProject;
    const formValues = {
      name,
      description,
      projectId: project.id,
    };

    beforeEach(() => {
      mockModalShow = jest.fn();

      createComponent();
      wrapper.vm.$refs.modal.show = mockModalShow;
    });

    it('sends a create request', async () => {
      await findForm().vm.$emit('submit', formValues);
      await waitForPromises();

      expect(createAiCatalogAgentMock).toHaveBeenCalledTimes(1);
      expect(createAiCatalogAgentMock).toHaveBeenCalledWith({
        input: { ...formValues, public: true },
      });
    });

    it('sets a loading state on the form while submitting', async () => {
      expect(findForm().props('isLoading')).toBe(false);

      await findForm().vm.$emit('submit', {});
      expect(findForm().props('isLoading')).toBe(true);
    });

    describe('when request fails', () => {
      it('shows an alert', async () => {
        createAiCatalogAgentMock.mockRejectedValue(new Error());
        await findForm().vm.$emit('submit', {});
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            captureError: true,
            error: expect.any(Error),
            message: expect.any(String),
          }),
        );
        expect(mockModalShow).not.toHaveBeenCalled();
        expect(findForm().props('isLoading')).toBe(false);
      });
    });

    describe('when request succeeds but returns error', () => {
      it('shows an alert', async () => {
        createAiCatalogAgentMock.mockResolvedValue(mockCreateAiCatalogAgentErrorMutation);
        await findForm().vm.$emit('submit', {});
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: mockCreateAiCatalogAgentErrorMutation.data.aiCatalogAgentCreate.errors[0],
        });
        expect(mockModalShow).not.toHaveBeenCalled();
        expect(findForm().props('isLoading')).toBe(false);
      });
    });

    describe('when request succeeds', () => {
      it('shows a modal', async () => {
        await findForm().vm.$emit('submit', formValues);
        await waitForPromises();

        expect(mockModalShow).toHaveBeenCalled();
        expect(createAlert).not.toHaveBeenCalled();
        expect(findForm().props('isLoading')).toBe(false);
      });
    });
  });
});
