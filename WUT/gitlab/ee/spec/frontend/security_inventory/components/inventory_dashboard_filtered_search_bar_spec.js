import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { queryToObject } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility', () => ({
  queryToObject: jest.fn().mockReturnValue({}),
  setUrlParams: jest.fn().mockReturnValue(''),
}));

describe('InventoryDashboardFilteredSearchBar', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(InventoryDashboardFilteredSearchBar, {
      propsData: {
        namespace: 'group1',
        ...props,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the filtered search component', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('passes the correct props to filtered search', () => {
      expect(findFilteredSearch().props()).toMatchObject({
        initialFilterValue: [],
        tokens: [],
        termsAsTokens: true,
      });
    });
  });

  describe('initialFilterValue', () => {
    it('use initialFilters prop when search is provided', () => {
      createComponent({
        props: {
          initialFilters: { search: 'test-search' },
        },
      });
      expect(findFilteredSearch().props('initialFilterValue')).toEqual(['test-search']);
    });

    it('use URL search parameter when available and initialFilters is not provided', () => {
      queryToObject.mockReturnValue({ search: 'url-search' });
      createComponent();
      expect(findFilteredSearch().props('initialFilterValue')).toEqual(['url-search']);
    });

    it('returns empty array when no search is available', () => {
      queryToObject.mockReturnValue({});
      createComponent();
      expect(findFilteredSearch().props('initialFilterValue')).toEqual([]);
    });
  });

  describe('onFilter method', () => {
    it('emits filterSubgroupsAndProjects event with search param when filtered with text', async () => {
      const searchTerm = 'test project';
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: searchTerm },
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      filters[0].search = searchTerm;
      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: searchTerm,
      });
    });

    it('emits filterSubgroupsAndProjects event with combined search terms when multiple terms are provided', async () => {
      const searchTerms = ['test', 'project'];
      const filters = searchTerms.map((term) => ({
        type: 'filtered-search-term',
        value: { data: term },
      }));
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: 'test project',
      });
    });

    it('emits filterSubgroupsAndProjects event with empty object when no search terms are provided', async () => {
      findFilteredSearch().vm.$emit('onFilter', []);
      await nextTick();
      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({});
    });

    it('skips filters without value data', async () => {
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: 'test search' },
        },
        {
          type: 'filtered-search-term',
          value: {},
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: 'test search',
      });
    });

    it('ignores non-text filter types', async () => {
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: 'test search' },
        },
        {
          type: 'other-type',
          value: { data: 'should be ignored' },
        },
      ];
      findFilteredSearch().vm.$emit('onFilter', filters);
      await nextTick();

      expect(wrapper.emitted('filterSubgroupsAndProjects')[0][0]).toEqual({
        search: 'test search',
      });
    });
  });
});
