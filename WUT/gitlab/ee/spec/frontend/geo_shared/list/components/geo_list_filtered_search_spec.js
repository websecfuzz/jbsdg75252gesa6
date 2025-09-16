import { GlFilteredSearch } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListFilteredSearch from 'ee/geo_shared/list/components/geo_list_filtered_search.vue';
import { MOCK_FILTERED_SEARCH_TOKENS, MOCK_FILTER_A } from '../mock_data';

describe('GeoListFilteredSearch', () => {
  let wrapper;

  const defaultProps = {
    activeFilters: [MOCK_FILTER_A],
  };

  const defaultProvide = {
    filteredSearchTokens: MOCK_FILTERED_SEARCH_TOKENS,
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoListFilteredSearch, {
      propsData,
      provide: {
        ...defaultProvide,
      },
    });
  };

  const findGlFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with active filters', () => {
      expect(findGlFilteredSearch().props('value')).toStrictEqual([MOCK_FILTER_A]);
    });

    it('renders with the provided tokens', () => {
      expect(findGlFilteredSearch().props('availableTokens')).toStrictEqual(
        MOCK_FILTERED_SEARCH_TOKENS,
      );
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('on submit event emits search to the parent with the passed arguments', async () => {
      findGlFilteredSearch().vm.$emit('submit', [MOCK_FILTER_A]);
      await nextTick();

      expect(wrapper.emitted('search')).toStrictEqual([[[MOCK_FILTER_A]]]);
    });
  });
});
