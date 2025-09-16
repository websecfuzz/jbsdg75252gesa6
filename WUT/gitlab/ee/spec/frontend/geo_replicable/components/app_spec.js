import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { BULK_ACTIONS, GEO_TROUBLESHOOTING_LINK } from 'ee/geo_replicable/constants';
import GeoFeedbackBanner from 'ee/geo_replicable/components/geo_feedback_banner.vue';
import GeoReplicableApp from 'ee/geo_replicable/components/app.vue';
import GeoReplicable from 'ee/geo_replicable/components/geo_replicable.vue';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import GeoReplicableFilterBar from 'ee/geo_replicable/components/geo_replicable_filter_bar.vue';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import initStore from 'ee/geo_replicable/store';
import { processFilters } from 'ee/geo_replicable/filters';
import { TEST_HOST } from 'spec/test_constants';
import setWindowLocation from 'helpers/set_window_location_helper';
import { setUrlParams, visitUrl } from '~/lib/utils/url_utility';
import {
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_TYPE,
  MOCK_GRAPHQL_REGISTRY,
  MOCK_REPLICABLE_TYPE_FILTER,
  MOCK_REPLICATION_STATUS_FILTER,
} from '../mock_data';

const MOCK_FILTERS = { foo: 'bar' };
const MOCK_PROCESSED_FILTERS = { query: MOCK_FILTERS, url: { href: 'mock-url/params' } };
const MOCK_UPDATED_URL = 'mock-url/params?foo=bar';

const MOCK_BASE_LOCATION = `${TEST_HOST}/admin/geo/sites/2/replication/${MOCK_REPLICABLE_TYPE_FILTER.value}`;
const MOCK_LOCATION_WITH_FILTERS = `${MOCK_BASE_LOCATION}?${MOCK_REPLICATION_STATUS_FILTER.type}=${MOCK_REPLICATION_STATUS_FILTER.value.data}`;

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  setUrlParams: jest.fn(() => MOCK_UPDATED_URL),
  visitUrl: jest.fn(),
}));

jest.mock('ee/geo_replicable/filters', () => ({
  ...jest.requireActual('ee/geo_replicable/filters'),
  processFilters: jest.fn(() => MOCK_PROCESSED_FILTERS),
}));

Vue.use(Vuex);

describe('GeoReplicableApp', () => {
  let wrapper;
  let store;

  const defaultProvide = {
    itemTitle: 'Test Item',
  };

  const MOCK_EMPTY_STATE = {
    title: `There are no ${defaultProvide.itemTitle} to show`,
    description:
      'No %{itemTitle} were found. If you believe this may be an error, please refer to the %{linkStart}Geo Troubleshooting%{linkEnd} documentation for more information.',
    itemTitle: defaultProvide.itemTitle,
    helpLink: GEO_TROUBLESHOOTING_LINK,
    hasFilters: false,
  };

  const createStore = (options) => {
    store = initStore({ replicableType: MOCK_REPLICABLE_TYPE, ...options });
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = ({ featureFlags = {} } = {}) => {
    wrapper = shallowMount(GeoReplicableApp, {
      store,
      provide: {
        ...defaultProvide,
        glFeatures: { ...featureFlags },
      },
    });
  };

  const findGeoReplicableContainer = () => wrapper.find('.geo-replicable-container');
  const findGeoReplicable = () => findGeoReplicableContainer().findComponent(GeoReplicable);
  const findGeoList = () => findGeoReplicableContainer().findComponent(GeoList);
  const findGeoReplicableFilterBar = () =>
    findGeoReplicableContainer().findComponent(GeoReplicableFilterBar);
  const findGeoListTopBar = () => findGeoReplicableContainer().findComponent(GeoListTopBar);
  const findGeoFeedbackBanner = () => wrapper.findComponent(GeoFeedbackBanner);

  describe.each`
    isLoading | replicableItems
    ${false}  | ${MOCK_BASIC_GRAPHQL_DATA}
    ${false}  | ${[]}
    ${true}   | ${MOCK_BASIC_GRAPHQL_DATA}
    ${true}   | ${[]}
  `(`template`, ({ isLoading, replicableItems }) => {
    beforeEach(() => {
      createStore({ graphqlFieldName: MOCK_GRAPHQL_REGISTRY });
      createComponent();
    });

    describe(`when isLoading is ${isLoading} and ${replicableItems.length ? 'does' : 'does not'} have replicableItems`, () => {
      beforeEach(() => {
        store.state.isLoading = isLoading;
        store.state.replicableItems = replicableItems;
      });

      it('renders GeoList with the correct params', () => {
        expect(findGeoList().props()).toStrictEqual({
          isLoading,
          hasItems: Boolean(replicableItems.length),
          emptyState: MOCK_EMPTY_STATE,
        });
      });

      it('renders GeoReplicable in the default slot of GeoList always', () => {
        expect(findGeoReplicable().exists()).toBe(true);
      });
    });
  });

  describe.each`
    geoReplicablesFilteredListView | hasFilters | mockLocation                  | statusFilter
    ${false}                       | ${false}   | ${MOCK_BASE_LOCATION}         | ${null}
    ${false}                       | ${true}    | ${MOCK_BASE_LOCATION}         | ${'test-filter'}
    ${true}                        | ${false}   | ${MOCK_BASE_LOCATION}         | ${undefined}
    ${true}                        | ${true}    | ${MOCK_LOCATION_WITH_FILTERS} | ${undefined}
  `(
    'empty state property',
    ({ geoReplicablesFilteredListView, hasFilters, mockLocation, statusFilter }) => {
      describe(`when feature geoReplicablesFilteredListView is set to ${geoReplicablesFilteredListView}`, () => {
        describe(`when filters are ${hasFilters}`, () => {
          beforeEach(() => {
            setWindowLocation(mockLocation);

            createStore();
            createComponent({ featureFlags: { geoReplicablesFilteredListView } });

            store.state.statusFilter = statusFilter;
            store.state.replicableItems = [];
          });

          it('renders GeoList with correct empty state prop', () => {
            expect(findGeoList().props('emptyState')).toStrictEqual({
              ...MOCK_EMPTY_STATE,
              hasFilters,
            });
          });
        });
      });
    },
  );

  describe('filter bar', () => {
    describe('when feature geoReplicablesFilteredListView is disabled', () => {
      beforeEach(() => {
        createStore();
        createComponent({ featureFlags: { geoReplicablesFilteredListView: false } });
      });

      it('renders filter bar', () => {
        expect(findGeoReplicableFilterBar().exists()).toBe(true);
      });

      it('does not render top bar', () => {
        expect(findGeoListTopBar().exists()).toBe(false);
      });
    });

    describe('when feature geoReplicablesFilteredListView is enabled', () => {
      describe('when no query is present', () => {
        beforeEach(() => {
          setWindowLocation(MOCK_BASE_LOCATION);

          createStore();
          createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
        });

        it('does not render filter bar', () => {
          expect(findGeoReplicableFilterBar().exists()).toBe(false);
        });

        it('renders top bar with correct listbox item and no search filters', () => {
          expect(findGeoListTopBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([]);
        });
      });

      describe('when query is present', () => {
        beforeEach(() => {
          setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

          createStore();
          createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
        });

        it('does not render filter bar', () => {
          expect(findGeoReplicableFilterBar().exists()).toBe(false);
        });

        it('renders top bar with correct listbox item and search filters', () => {
          expect(findGeoListTopBar().props('activeListboxItem')).toBe(
            MOCK_REPLICABLE_TYPE_FILTER.value,
          );
          expect(findGeoListTopBar().props('activeFilteredSearchFilters')).toStrictEqual([
            MOCK_REPLICATION_STATUS_FILTER,
          ]);
        });
      });
    });
  });

  describe('bulk actions', () => {
    beforeEach(() => {
      createStore();
      createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
    });

    describe('with no replicable items', () => {
      beforeEach(() => {
        store.state.replicableItems = [];
      });

      it('renders top bar with showActions=false', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(false);
      });
    });

    describe('with replicable items', () => {
      beforeEach(() => {
        store.state.replicableItems = MOCK_BASIC_GRAPHQL_DATA;
      });

      it('renders top bar with showActions=true and correct actions', () => {
        expect(findGeoListTopBar().props('showActions')).toBe(true);
        expect(findGeoListTopBar().props('bulkActions')).toStrictEqual(BULK_ACTIONS);
      });

      it('when top bar emits @bulkAction, initiateAllReplicableAction is called with correct action', async () => {
        findGeoListTopBar().vm.$emit('bulkAction', BULK_ACTIONS[0].action);
        await nextTick();

        expect(store.dispatch).toHaveBeenCalledWith('initiateAllReplicableAction', {
          action: BULK_ACTIONS[0].action,
        });
      });
    });
  });

  describe('banner', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the Geo Feedback Banner', () => {
      expect(findGeoFeedbackBanner().exists()).toBe(true);
    });
  });

  describe('handleListboxChange', () => {
    beforeEach(() => {
      setWindowLocation(MOCK_LOCATION_WITH_FILTERS);

      createStore();
      createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
    });

    it('preserves filters while updating the replicable type before calling processFilters and visitUrl', () => {
      const MOCK_NEW_REPLICABLE_TYPE = 'new_replicable_type';

      findGeoListTopBar().vm.$emit('listboxChange', MOCK_NEW_REPLICABLE_TYPE);

      expect(processFilters).toHaveBeenCalledWith([
        { type: MOCK_REPLICABLE_TYPE_FILTER.type, value: MOCK_NEW_REPLICABLE_TYPE },
        { type: MOCK_REPLICATION_STATUS_FILTER.type, value: MOCK_REPLICATION_STATUS_FILTER.value },
      ]);
      expect(setUrlParams).toHaveBeenCalledWith(
        MOCK_PROCESSED_FILTERS.query,
        MOCK_PROCESSED_FILTERS.url.href,
        true,
      );
      expect(visitUrl).toHaveBeenCalledWith(MOCK_UPDATED_URL);
    });
  });

  describe('handleSearch', () => {
    beforeEach(() => {
      createStore();
      createComponent({ featureFlags: { geoReplicablesFilteredListView: true } });
    });

    it('processes filters and calls visitUrl', () => {
      findGeoListTopBar().vm.$emit('search', MOCK_FILTERS);

      expect(processFilters).toHaveBeenCalledWith(MOCK_FILTERS);
      expect(setUrlParams).toHaveBeenCalledWith(
        MOCK_PROCESSED_FILTERS.query,
        MOCK_PROCESSED_FILTERS.url.href,
        true,
      );
      expect(visitUrl).toHaveBeenCalledWith(MOCK_UPDATED_URL);
    });
  });

  describe('onCreate', () => {
    beforeEach(() => {
      createStore();
      createComponent();
    });

    it('calls fetchReplicableItems', () => {
      expect(store.dispatch).toHaveBeenCalledWith('fetchReplicableItems');
    });
  });
});
