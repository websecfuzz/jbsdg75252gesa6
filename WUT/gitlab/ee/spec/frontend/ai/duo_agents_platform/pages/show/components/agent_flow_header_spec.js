import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowHeader from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_header.vue';

describe('AgentFlowHeader', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowHeader, {
      propsData: {
        isLoading: false,
        agentFlowDefinition: 'Software development',
        ...props,
      },
      mocks: {
        $route: {
          params: { id: '123' },
        },
      },
    });
  };

  const findHeading = () => wrapper.find('h1');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true });
    });

    it('renders the loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render the heading or prompt text', () => {
      expect(findHeading().exists()).toBe(false);
    });
  });

  describe('when loaded', () => {
    describe('with workflow definition', () => {
      beforeEach(() => {
        createComponent({ prompt: 'This is a test prompt' });
      });

      it('renders the workflow header title', () => {
        expect(findHeading().text()).toBe('Software development #123');
      });
    });

    describe('without a workflow definition', () => {
      beforeEach(() => {
        createComponent({ agentFlowDefinition: '' });
      });

      it('renders the default workflow header title', () => {
        expect(findHeading().text()).toBe('Agent session #123');
      });
    });
  });
});
