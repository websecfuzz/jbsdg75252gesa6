import { GlCollapsibleListbox, GlSearchBoxByType } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableFilterBar from 'ee/geo_replicable/components/geo_replicable_filter_bar.vue';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import { FILTER_OPTIONS, FILTER_STATES, BULK_ACTIONS } from 'ee/geo_replicable/constants';
import { MOCK_REPLICABLE_TYPE, MOCK_BASIC_GRAPHQL_DATA } from '../mock_data';

Vue.use(Vuex);

describe('GeoReplicableFilterBar', () => {
  let wrapper;

  const actionSpies = {
    setSearch: jest.fn(),
    setStatusFilter: jest.fn(),
    fetchReplicableItems: jest.fn(),
    initiateAllReplicableAction: jest.fn(),
  };

  const defaultState = {
    replicableItems: MOCK_BASIC_GRAPHQL_DATA,
    verificationEnabled: true,
    titlePlural: MOCK_REPLICABLE_TYPE,
  };

  const createComponent = (initialState = {}, featureFlags = {}) => {
    const store = new Vuex.Store({
      state: { ...defaultState, ...initialState },
      actions: actionSpies,
    });

    wrapper = shallowMountExtended(GeoReplicableFilterBar, {
      store,
      provide: { glFeatures: { ...featureFlags } },
    });
  };

  const findNavContainer = () => wrapper.find('nav');
  const findGlCollapsibleListbox = () => findNavContainer().findComponent(GlCollapsibleListbox);
  const findGlSearchBox = () => findNavContainer().findComponent(GlSearchBoxByType);
  const findBulkActions = () => wrapper.findComponent(GeoListBulkActions);

  const getFilterItems = (filters) => {
    return filters.map((filter) => {
      if (filter.value === FILTER_STATES.ALL.value) {
        return { ...filter, text: `${filter.label} ${MOCK_REPLICABLE_TYPE}` };
      }

      return { ...filter, text: filter.label };
    });
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the nav container', () => {
      expect(findNavContainer().exists()).toBe(true);
    });

    it('renders the GlCollapsibleListbox', () => {
      expect(findGlCollapsibleListbox().exists()).toBe(true);
    });

    it('properly formats the dropdownItems', () => {
      expect(findGlCollapsibleListbox().props('items')).toStrictEqual(
        getFilterItems(FILTER_OPTIONS),
      );
    });

    it('does not render search box', () => {
      expect(findGlSearchBox().exists()).toBe(false);
    });

    describe.each`
      replicableItems            | bulkActions
      ${[]}                      | ${false}
      ${MOCK_BASIC_GRAPHQL_DATA} | ${BULK_ACTIONS}
    `('Bulk Actions', ({ replicableItems, bulkActions }) => {
      beforeEach(() => {
        createComponent({ replicableItems });
      });

      it(`does ${bulkActions ? '' : 'not '}render Bulk Actions with correct actions`, () => {
        expect(findBulkActions().exists() && findBulkActions().props('bulkActions')).toBe(
          bulkActions,
        );
      });
    });
  });

  describe('handleBulkAction', () => {
    beforeEach(() => {
      createComponent({ replicableItems: MOCK_BASIC_GRAPHQL_DATA });
    });

    it('calls initiateAllReplicableAction with correct action', async () => {
      findBulkActions().vm.$emit('bulkAction', BULK_ACTIONS[0].action);
      await nextTick();

      expect(actionSpies.initiateAllReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
        action: BULK_ACTIONS[0].action,
      });
    });
  });

  describe('Filter Selected', () => {
    beforeEach(() => {
      createComponent();
    });

    it('clicking a filter item calls setStatusFilter with value and fetchReplicableItems', () => {
      const index = 1;
      findGlCollapsibleListbox().vm.$emit('select', FILTER_OPTIONS[index].value);

      expect(actionSpies.setStatusFilter).toHaveBeenCalledWith(
        expect.any(Object),
        FILTER_OPTIONS[index].value,
      );
      expect(actionSpies.fetchReplicableItems).toHaveBeenCalled();
    });
  });

  // To be implemented via https://gitlab.com/gitlab-org/gitlab/-/issues/411982
  describe('Search box actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render GlSearchBox', () => {
      expect(findGlSearchBox().exists()).toBe(false);
    });
  });
});
