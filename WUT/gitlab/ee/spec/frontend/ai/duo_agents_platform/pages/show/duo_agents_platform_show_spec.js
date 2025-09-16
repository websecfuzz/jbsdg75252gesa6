import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import DuoAgentsPlatformShow from 'ee/ai/duo_agents_platform/pages/show/duo_agents_platform_show.vue';
import AgentFlowDetails from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_details.vue';
import { DUO_AGENTS_PLATFORM_POLLING_INTERVAL } from 'ee/ai/duo_agents_platform/constants';
import { getAgentFlow } from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flow.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';
import { TYPENAME_AI_DUO_WORKFLOW } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';

import { mockGetAgentFlowResponse } from '../../../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('DuoAgentsPlatformShow', () => {
  let wrapper;

  let getAgentFlowHandler;

  const agentFlowId = '1';
  const graphqlWorkflowId = convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, agentFlowId);
  const defaultMockRoute = {
    params: {
      id: agentFlowId,
    },
  };

  const createWrapper = (props = {}, mockRoute = defaultMockRoute) => {
    const handlers = [[getAgentFlow, getAgentFlowHandler]];

    wrapper = shallowMount(DuoAgentsPlatformShow, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        ...props,
      },
      mocks: {
        $route: mockRoute,
      },
    });

    return waitForPromises();
  };

  const findAgentFlowDetails = () => wrapper.findComponent(AgentFlowDetails);

  beforeEach(() => {
    getAgentFlowHandler = jest.fn().mockResolvedValue(mockGetAgentFlowResponse);
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the AgentFlowDetails component', () => {
      expect(findAgentFlowDetails().exists()).toBe(true);
    });

    it('passes correct props to AgentFlowDetails', () => {
      const workflowDetailsProps = findAgentFlowDetails().props();

      expect(workflowDetailsProps).toEqual({
        isLoading: false,
        status: 'Running',
        agentFlowDefinition: 'Software development',
        agentFlowCheckpoint:
          mockGetAgentFlowResponse.data.duoWorkflowWorkflows.edges[0].node.firstCheckpoint
            .checkpoint,
      });
    });
  });

  describe('Apollo queries', () => {
    describe('agentFlowEvents query', () => {
      describe('when loading', () => {
        beforeEach(() => {
          // Not awaiting here simulates the loading state
          createWrapper();
        });

        it('passes the loading state to the details component', () => {
          expect(findAgentFlowDetails().props().isLoading).toBe(true);
        });
      });

      describe('on successful response', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockResolvedValue(mockGetAgentFlowResponse);
          await createWrapper();
        });

        it('fetches workflow events data with correct variables', () => {
          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);
          expect(getAgentFlowHandler).toHaveBeenCalledWith({
            workflowId: graphqlWorkflowId,
          });
        });

        it('does not show an error', () => {
          expect(createAlert).not.toHaveBeenCalled();
        });

        it('passes the loading state to the details component as false', () => {
          expect(findAgentFlowDetails().props().isLoading).toBe(false);
        });
      });

      describe('when agentFlowEvents query fails', () => {
        const errorMessage = 'Network error';

        beforeEach(async () => {
          getAgentFlowHandler.mockRejectedValue(new Error(errorMessage));
          await createWrapper();
        });

        it('calls createAlert with the error message', () => {
          expect(createAlert).toHaveBeenCalledWith({ message: errorMessage });
        });
      });

      describe('when error occurs without message', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockRejectedValue(new Error(''));
          await createWrapper();
        });

        it('calls createAlert with default error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Something went wrong while fetching Agent Flows',
          });
        });
      });

      describe('polling', () => {
        beforeEach(async () => {
          getAgentFlowHandler.mockResolvedValue(mockGetAgentFlowResponse);
          await createWrapper();
        });

        it('polls after 10 seconds', async () => {
          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(3000);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(1);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(2);

          jest.advanceTimersByTime(DUO_AGENTS_PLATFORM_POLLING_INTERVAL);
          await waitForPromises();

          expect(getAgentFlowHandler).toHaveBeenCalledTimes(3);
        });
      });
    });
  });

  describe('route parameter handling', () => {
    it('converts route id to GraphQL ID correctly', async () => {
      const customWorkflowId = '123';

      wrapper = createWrapper(
        {},
        {
          params: {
            id: customWorkflowId,
          },
        },
      );

      await waitForPromises();

      expect(getAgentFlowHandler).toHaveBeenCalledWith({
        workflowId: convertToGraphQLId(TYPENAME_AI_DUO_WORKFLOW, customWorkflowId),
      });
    });
  });
});
