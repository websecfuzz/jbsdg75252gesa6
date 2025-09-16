import { GlFilteredSearch } from '@gitlab/ui';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FilteredSearch from 'ee/security_dashboard/components/shared/security_dashboard_filtered_search/filtered_search.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';

const TEST_TOKEN_DEFINITION = {
  type: 'testTokenId',
  title: 'Test Token',
  multiSelect: true,
  unique: true,
  token: markRaw(() => {}),
  operators: OPERATORS_OR,
};

describe('Security Dashboard Filtered Search', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(FilteredSearch, {
      propsData: {
        tokens: [TEST_TOKEN_DEFINITION],
        ...props,
      },
    });
  };

  beforeEach(createWrapper);

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  it('renders `GlFilteredSearch` with correct props', () => {
    const filteredSearch = findFilteredSearch();

    expect(filteredSearch.props('placeholder')).toBe('Filter results...');
    expect(filteredSearch.props('availableTokens')).toHaveLength(1);
    expect(filteredSearch.props('availableTokens')[0].title).toBe('Test Token');
    expect(filteredSearch.props('value')).toEqual([]);
  });

  it('emits `filters-changed` with the given `projectId` when input is valid', () => {
    const input = [{ type: 'testTokenId', value: { data: ['5', '10'] } }];

    findFilteredSearch().vm.$emit('input', input);

    expect(wrapper.emitted('filters-changed')).toEqual([[{ testTokenId: ['5', '10'] }]]);
  });

  it('does not emit `filters-changed` when input is invalid', () => {
    const input = [{ type: 'testTokenId', value: { data: null } }];

    findFilteredSearch().vm.$emit('input', input);

    expect(wrapper.emitted('filters-changed')).toBeUndefined();
  });

  it('emits `filters-changed` with empty filters on `clear`', () => {
    findFilteredSearch().vm.$emit('clear');

    expect(wrapper.emitted('filters-changed')).toEqual([[{}]]);
  });

  it('emits `filters-changed` with empty filters when input is empty', () => {
    findFilteredSearch().vm.$emit('input', []);

    expect(wrapper.emitted('filters-changed')).toEqual([[{}]]);
  });
});
