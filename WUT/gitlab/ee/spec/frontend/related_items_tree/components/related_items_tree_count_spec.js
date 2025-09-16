import { GlPopover, GlSprintf, GlIcon, GlAlert } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import EpicCountables from 'ee/vue_shared/components/epic_countables/epic_countables.vue';
import EpicHealthStatus from 'ee/related_items_tree/components/epic_health_status.vue';
import RelatedItemsTreeCount from 'ee/related_items_tree/components/related_items_tree_count.vue';
import createDefaultStore from 'ee/related_items_tree/store';
import * as epicUtils from 'ee/related_items_tree/utils/epic_utils';

import { mockInitialConfig, mockParentItem, mockQueryResponse } from '../mock_data';

Vue.use(Vuex);

const createComponent = ({ slots, isOpenString } = { isOpenString: 'expanded' }) => {
  const store = createDefaultStore();
  const children = epicUtils.processQueryResponse(mockQueryResponse.data.group);

  store.dispatch('setInitialConfig', mockInitialConfig);
  store.dispatch('setInitialParentItem', mockParentItem);
  store.dispatch('setItemChildren', {
    parentItem: mockParentItem,
    isSubItem: false,
    children,
  });
  store.dispatch('setItemChildrenFlags', {
    isSubItem: false,
    children,
  });
  store.dispatch('setWeightSum', {
    openedIssues: 10,
    closedIssues: 5,
  });
  store.dispatch('setChildrenCount', mockParentItem.descendantCounts);

  return shallowMountExtended(RelatedItemsTreeCount, {
    store,
    slots,
    propsData: {
      isOpenString,
    },
    stubs: {
      GlSprintf,
      EpicCountables,
    },
  });
};

describe('RelatedItemsTree', () => {
  describe('RelatedItemsTreeHeader', () => {
    let wrapper;

    describe('Count popover', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it('returns string containing epic count based on available direct children within state', () => {
        expect(wrapper.findComponent(GlPopover).text()).toMatch(/Epics •\n\s+1 open, 1 closed/);
      });

      it('returns string containing issue count based on available direct children within state', () => {
        expect(wrapper.findComponent(GlPopover).text()).toMatch(/Issues •\n\s+2 open, 1 closed/);
      });

      it('displays warning', () => {
        expect(wrapper.findComponent(GlAlert).text()).toBe(
          'Counts reflect children you may not have access to.',
        );
      });
    });

    describe('totalWeight', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it('total of openedIssues and closedIssues weight', () => {
        expect(wrapper.findComponent(GlPopover).text()).toMatch(/Total weight •\n\s+15/);
      });
    });

    describe('template', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it('renders item badges container', () => {
        const badgesContainerEl = wrapper.find('.issue-count-badge');

        expect(badgesContainerEl.isVisible()).toBe(true);
      });

      it('renders epics count and gl-icon', () => {
        const epicsEl = wrapper.findAll('.issue-count-badge > span').at(0);
        const epicIcon = epicsEl.findComponent(GlIcon);

        expect(epicsEl.text().trim()).toContain('2');
        expect(epicIcon.isVisible()).toBe(true);
        expect(epicIcon.props('name')).toBe('epic');
      });

      describe('when issuable-health-status feature is not available', () => {
        beforeEach(async () => {
          wrapper.vm.$store.commit('SET_INITIAL_CONFIG', {
            ...mockInitialConfig,
            allowIssuableHealthStatus: false,
          });

          await nextTick();
        });

        it('does not render health status', () => {
          expect(wrapper.findComponent(EpicHealthStatus).exists()).toBe(false);
        });
      });

      describe('when issuable-health-status feature is available', () => {
        beforeEach(async () => {
          wrapper.vm.$store.commit('SET_INITIAL_CONFIG', {
            ...mockInitialConfig,
            allowIssuableHealthStatus: true,
          });

          await nextTick();
        });

        it('does not render health status', () => {
          expect(wrapper.findComponent(EpicHealthStatus).exists()).toBe(true);
        });
      });

      it('renders issues count and gl-icon', () => {
        const issuesEl = wrapper.findAll('.issue-count-badge > span').at(1);
        const issueIcon = issuesEl.findComponent(GlIcon);

        expect(issuesEl.text().trim()).toContain('3');
        expect(issueIcon.isVisible()).toBe(true);
        expect(issueIcon.props('name')).toBe('issues');
      });

      it('renders totalWeight count and gl-icon', () => {
        const weightEl = wrapper.findAll('.issue-count-badge > span').at(2);
        const weightIcon = weightEl.findComponent(GlIcon);

        expect(weightEl.text().trim()).toContain('15');
        expect(weightIcon.isVisible()).toBe(true);
        expect(weightIcon.props('name')).toBe('weight');
      });
    });
  });
});
