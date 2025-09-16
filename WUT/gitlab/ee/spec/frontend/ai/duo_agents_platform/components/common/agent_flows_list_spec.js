import { GlEmptyState, GlLink, GlTableLite, GlKeysetPagination } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import { mockAgentFlows } from '../../../mocks';

describe('AgentFlowList', () => {
  let wrapper;

  const createWrapper = (props = {}, mountFn = mount) => {
    wrapper = mountFn(AgentFlowList, {
      propsData: {
        workflows: mockAgentFlows,
        workflowsPageInfo: {},
        emptyStateIllustrationPath: 'illustrations/empty-state/empty-pipeline-md.svg',
        ...props,
      },
      stubs: {
        GlTableLite,
        RouterLink: true,
      },
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findAgentNameLink = () => findTable().findAllComponents(GlLink);

  describe('when component is mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('and there are no workflows', () => {
      beforeEach(async () => {
        await createWrapper({ workflows: [] });
      });

      it('renders the emptyState', () => {
        expect(findEmptyState().exists()).toBe(true);
        expect(findEmptyState().props()).toMatchObject({
          title: 'No agent sessions yet',
          description: 'New agent sessions will appear here.',
          svgPath: 'illustrations/empty-state/empty-pipeline-md.svg',
        });
      });

      it('does not render the table', () => {
        expect(findTable().exists()).toBe(false);
      });
    });

    describe('when there are workflows', () => {
      it('renders the table component', () => {
        expect(findTable().exists()).toBe(true);
      });

      it('passes the correct fields to the table', () => {
        const expectedFields = [
          { key: 'workflowDefinition', label: 'Name' },
          { key: 'humanStatus', label: 'Status' },
          { key: 'updatedAt', label: 'Updated' },
          { key: 'id', label: 'ID' },
        ];

        expect(findTable().props('fields')).toEqual(expectedFields);
      });

      it('renders workflows as items to the table', () => {
        expect(findTable().text()).toContain('Software development #1');
        expect(findTable().text()).toContain('Convert to ci #2');
      });

      it('renders the status formatted', () => {
        expect(findTable().text()).toContain('Completed');
        expect(findTable().text()).toContain('Running');
      });

      describe('workflowDefinition column', () => {
        it('each goal cell is wrapped in a gl-link', () => {
          expect(findAgentNameLink()).toHaveLength(2); // from mockAgentFlows.length
          expect(findAgentNameLink().at(0).props('to').name).toBe('agents_platform_show_route');
          expect(findAgentNameLink().at(0).props('to').params).toEqual({
            id: 1,
          });
        });
      });
    });
  });

  describe('keyset pagination controls', () => {
    describe('when there is no pagination data', () => {
      beforeEach(() => {
        createWrapper({
          workflowsPageInfo: {},
        });
      });

      it('does not render pagination controls', () => {
        expect(findKeysetPagination().isVisible()).toBe(false);
      });
    });
    describe('when there is pagination data', () => {
      const paginationData = {
        startCursor: 'start',
        endCursor: 'end',
        hasNextPage: true,
        hasPreviousPage: false,
      };

      beforeEach(() => {
        createWrapper({
          workflowsPageInfo: paginationData,
        });
      });

      it('renders pagination controls', () => {
        expect(findKeysetPagination().isVisible()).toBe(true);
      });

      it('binds the correct page info to pagination controls', () => {
        expect(findKeysetPagination().props()).toMatchObject(paginationData);
      });

      describe('when clicking on the next page', () => {
        beforeEach(() => {
          findKeysetPagination().vm.$emit('next');
        });

        it('emit next-page', () => {
          expect(wrapper.emitted('next-page')).toHaveLength(1);
        });
      });

      describe('when clicking on the previous page', () => {
        beforeEach(() => {
          findKeysetPagination().vm.$emit('prev');
        });

        it('emit prev-page', () => {
          expect(wrapper.emitted('prev-page')).toHaveLength(1);
        });
      });
    });
  });
});
