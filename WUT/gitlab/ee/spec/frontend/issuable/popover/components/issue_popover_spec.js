import { GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import issueQueryResponse from 'test_fixtures/ee/graphql/issuable/popover/queries/issue.query.graphql.json';
import issueQuery from 'ee_else_ce/issuable/popover/queries/issue.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import IssuePopover from '~/issuable/popover/components/issue_popover.vue';
import IssueWeight from 'ee_component/issues/components/issue_weight.vue';

describe('Issue Popover', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  Vue.use(VueApollo);

  const findGlPopover = () => wrapper.findComponent(GlPopover);

  const mountComponent = ({
    queryResponse = jest.fn().mockResolvedValue(issueQueryResponse),
  } = {}) => {
    wrapper = shallowMount(IssuePopover, {
      apolloProvider: createMockApollo([[issueQuery, queryResponse]]),
      propsData: {
        target: document.createElement('a'),
        namespacePath: 'foo/bar',
        iid: '1',
        cachedTitle: 'Cached title',
      },
      stubs: {
        IssueWeight,
      },
    });
  };

  describe('when loaded', () => {
    beforeEach(async () => {
      mountComponent();
      findGlPopover().vm.$emit('show');
      await waitForPromises();
    });

    it('shows weight', () => {
      const component = wrapper.findComponent(IssueWeight);

      expect(component.exists()).toBe(true);
      expect(component.props('weight')).toBe(3);
    });
  });
});
