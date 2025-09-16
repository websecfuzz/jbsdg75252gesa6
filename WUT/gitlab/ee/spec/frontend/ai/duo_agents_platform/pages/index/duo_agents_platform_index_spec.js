import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';

import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import AgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';
import { getAgentFlows } from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flows.query.graphql';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';
import { mockAgentFlowsResponse } from '../../../mocks';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('AgentsPlatformIndex', () => {
  let wrapper;
  const getAgentFlowsHandler = jest.fn();

  const projectPath = 'project/path';

  const createWrapper = (props = {}) => {
    const handlers = [[getAgentFlows, getAgentFlowsHandler]];

    wrapper = shallowMount(AgentsPlatformIndex, {
      apolloProvider: createMockApollo(handlers),
      propsData: props,
      provide: {
        projectPath,
        emptyStateIllustrationPath: 'illustrations/empty-state/empty-pipeline-md.svg',
      },
    });

    return waitForPromises();
  };

  const findWorkflowsList = () => wrapper.findComponent(AgentFlowList);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findNewAgentFlowButton = () => wrapper.find('[data-testid="new-agent-flow-button"]');

  beforeEach(() => {
    getAgentFlowsHandler.mockResolvedValue(mockAgentFlowsResponse);
  });

  describe('when loading the queries', () => {
    beforeEach(() => {
      // Not awaiting here simulates loading
      createWrapper();
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the workflow list', () => {
      expect(findWorkflowsList().exists()).toBe(false);
    });
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the workflows list component', () => {
      expect(findWorkflowsList().exists()).toBe(true);
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders the new agent flow button', () => {
      expect(findNewAgentFlowButton().exists()).toBe(true);
    });
  });

  describe('Apollo queries', () => {
    describe('workflows query', () => {
      describe('on successful fetch', () => {
        beforeEach(async () => {
          await createWrapper();
        });

        it('fetches workflows data', () => {
          expect(getAgentFlowsHandler).toHaveBeenCalledTimes(1);
          expect(getAgentFlowsHandler).toHaveBeenCalledWith({
            projectPath,
            before: null,
            first: 20,
            last: null,
          });
        });

        it('passes workflows to AgentFlowList component', () => {
          const expectedWorkflows = mockAgentFlowsResponse.data.duoWorkflowWorkflows.edges.map(
            (w) => w.node,
          );

          expect(findWorkflowsList().props('workflows')).toEqual(expectedWorkflows);
        });
      });

      describe('when workflows query fails', () => {
        const errorMessage = 'Network error';

        beforeEach(async () => {
          getAgentFlowsHandler.mockRejectedValue(new Error(errorMessage));
          await createWrapper();
        });

        it('calls createAlert with the error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: errorMessage,
            captureError: true,
          });
        });

        it('passes empty array to AgentFlowList component', () => {
          expect(findWorkflowsList().props('workflows')).toEqual([]);
        });
      });

      describe('when workflows query returns no data', () => {
        beforeEach(async () => {
          getAgentFlowsHandler.mockResolvedValue({
            data: {
              duoWorkflowWorkflows: {
                edges: [],
                pageInfo: {
                  startCursor: null,
                  endCursor: null,
                  hasNextPage: false,
                  hasPreviousPage: false,
                },
              },
            },
          });
          await createWrapper();
        });

        it('passes empty array to AgentFlowList component', () => {
          expect(findWorkflowsList().props('workflows')).toEqual([]);
        });

        it('passes empty page info to AgentFlowList component', () => {
          expect(findWorkflowsList().props('workflowsPageInfo')).toEqual({
            startCursor: null,
            endCursor: null,
            hasNextPage: false,
            hasPreviousPage: false,
          });
        });
      });

      describe('when workflows query returns empty edges', () => {
        beforeEach(async () => {
          getAgentFlowsHandler.mockResolvedValue({
            data: {
              duoWorkflowWorkflows: {
                pageInfo: {
                  startCursor: null,
                  endCursor: null,
                  hasNextPage: false,
                  hasPreviousPage: false,
                },
                edges: [],
              },
            },
          });
          await createWrapper();
        });

        it('passes empty array to AgentFlowList component', () => {
          expect(findWorkflowsList().props('workflows')).toEqual([]);
        });

        it('passes correct page info to AgentFlowList component', () => {
          const expectedPageInfo = {
            startCursor: null,
            endCursor: null,
            hasNextPage: false,
            hasPreviousPage: false,
          };
          expect(findWorkflowsList().props('workflowsPageInfo')).toEqual(expectedPageInfo);
        });
      });
    });

    describe('pagination', () => {
      beforeEach(async () => {
        await createWrapper();
      });

      describe('when next page is requested', () => {
        it('calls refetch with correct parameters', () => {
          findWorkflowsList().vm.$emit('next-page');

          expect(getAgentFlowsHandler).toHaveBeenCalledWith({
            projectPath,
            after: 'end',
            last: null,
            before: null,
            first: 20,
          });
        });

        it('correctly refetches data when next-page event is emitted', async () => {
          // Create mock data for the second page
          const secondPageWorkflowEdges = [
            {
              node: {
                __typename: 'DuoWorkflow',
                id: 'gid://gitlab/DuoWorkflow::Workflow/3',
                humanStatus: 'pending',
                updatedAt: '2024-01-03T00:00:00Z',
                workflowDefinition: 'software_development',
              },
            },
            {
              node: {
                __typename: 'DuoWorkflow',
                id: 'gid://gitlab/DuoWorkflow::Workflow/4',
                humanStatus: 'failed',
                updatedAt: '2024-01-04T00:00:00Z',
                workflowDefinition: 'convert_to_ci',
              },
            },
          ];

          const secondPageResponse = {
            data: {
              duoWorkflowWorkflows: {
                pageInfo: {
                  startCursor: 'start2',
                  endCursor: 'end2',
                  hasNextPage: false,
                  hasPreviousPage: true,
                },
                edges: secondPageWorkflowEdges,
              },
            },
          };

          // Reset the handler and set up the chain of responses
          getAgentFlowsHandler.mockReset();
          getAgentFlowsHandler
            .mockResolvedValueOnce(mockAgentFlowsResponse) // First call returns initial data
            .mockResolvedValueOnce(secondPageResponse); // Second call returns second page data

          // Create a new wrapper to get fresh data
          await createWrapper();

          // Assert initial data is passed as props
          const initialWorkflows = mockAgentFlowsResponse.data.duoWorkflowWorkflows.edges.map(
            (w) => w.node,
          );
          expect(findWorkflowsList().props('workflows')).toEqual(initialWorkflows);

          // Emit the next-page event
          findWorkflowsList().vm.$emit('next-page');
          await waitForPromises();

          // Assert that refetch was called with correct parameters
          expect(getAgentFlowsHandler).toHaveBeenCalledWith({
            projectPath,
            after: 'end',
            before: null,
            first: 20,
            last: null,
          });

          // Assert that the new data (second page) is now passed as props
          const expectedSecondPageWorkflows = secondPageWorkflowEdges.map((w) => w.node);
          expect(findWorkflowsList().props('workflows')).toEqual(expectedSecondPageWorkflows);
        });
      });

      describe('when previous page is requested', () => {
        it('calls refetch with correct parameters', () => {
          findWorkflowsList().vm.$emit('prev-page');

          expect(getAgentFlowsHandler).toHaveBeenCalledWith({
            projectPath,
            after: null,
            before: 'start',
            last: 20,
            first: null,
          });
        });
      });
    });
  });
});
