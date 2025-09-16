import { GlTableLite, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { RouterLinkStub as RouterLink } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AgentList from 'ee/ml/ai_agents/components/agent_list.vue';
import getAiAgentsQuery from 'ee/ml/ai_agents/graphql/queries/get_ai_agents.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { listAiAgentsResponses, listAiAgentsEmptyResponses } from '../graphql/mocks';

Vue.use(VueApollo);

describe('AI Agents List View', () => {
  let wrapper;

  const createComponent = ({ apolloProvider }) => {
    wrapper = mountExtended(AgentList, {
      apolloProvider,
      provide: { projectPath: 'path/to/project' },
      propsData: { createAgentPath: 'path/to/create' },
      stubs: {
        RouterLink,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  describe('when the data is loading', () => {
    beforeEach(async () => {
      const apolloProvider = createMockApollo([
        [getAiAgentsQuery, jest.fn().mockReturnValueOnce(new Promise(() => {}))],
      ]);
      createComponent({ apolloProvider });
      await waitForPromises();
    });

    it('shows the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when no records exist', () => {
    beforeEach(async () => {
      const apolloProvider = createMockApollo([
        [getAiAgentsQuery, jest.fn().mockReturnValueOnce(listAiAgentsEmptyResponses)],
      ]);
      createComponent({ apolloProvider });
      await waitForPromises();
    });

    it('shows the empty state view', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props('svgPath')).toBe('file-mock');
    });
  });

  describe('when the data has successfully loaded', () => {
    beforeEach(async () => {
      const apolloProvider = createMockApollo([
        [getAiAgentsQuery, jest.fn().mockResolvedValueOnce(listAiAgentsResponses)],
      ]);

      createComponent({ apolloProvider });
      await waitForPromises();
    });

    it('renders the agents in a table view', () => {
      expect(findTable().text()).toContain('agent-1');
    });
  });
});
