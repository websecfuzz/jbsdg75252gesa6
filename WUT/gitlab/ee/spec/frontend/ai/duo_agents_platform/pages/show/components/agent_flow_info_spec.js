import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowInfo from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_info.vue';

describe('AgentFlowInfo', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowInfo, {
      propsData: {
        isLoading: false,
        status: 'RUNNING',
        agentFlowDefinition: 'software_development',
        ...props,
      },
    });
  };

  const findListItems = () => wrapper.findAll('li');
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
        status: 'RUNNING',
        agentFlowDefinition: 'software_development',
      });
    });

    it('renders UI copy as usual', () => {
      expect(findListItems()).toHaveLength(2);
    });

    it('displays the skeleton loaders', () => {
      expect(findSkeletonLoaders()).toHaveLength(2);
    });

    it('does not display placeholder N/A values', () => {
      expect(wrapper.text()).not.toContain('N/A');
    });
  });

  describe('info data', () => {
    it.each`
      status       | agentFlowDefinition       | expectedStatus | expectedType
      ${'STOPPED'} | ${'software_development'} | ${'STOPPED'}   | ${'software_development'}
      ${'STARTED'} | ${'testing'}              | ${'STARTED'}   | ${'testing'}
      ${''}        | ${'something_else'}       | ${'N/A'}       | ${'something_else'}
      ${'RUNNING'} | ${''}                     | ${'RUNNING'}   | ${'N/A'}
      ${''}        | ${''}                     | ${'N/A'}       | ${'N/A'}
    `(
      'renders expected values when status is $status and definition is `$workflowDefinition`',
      ({ status, agentFlowDefinition, expectedStatus, expectedType }) => {
        createComponent({ status, agentFlowDefinition });

        expect(findListItems().at(0).text()).toContain(`Status: ${expectedStatus}`);
        expect(findListItems().at(1).text()).toContain(`Type: ${expectedType}`);
      },
    );
  });
});
