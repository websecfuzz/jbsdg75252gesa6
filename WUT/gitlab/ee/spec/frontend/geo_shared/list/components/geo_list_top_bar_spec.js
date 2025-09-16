import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoListFilteredSearchBar from 'ee/geo_shared/list/components/geo_list_filtered_search_bar.vue';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import { MOCK_LISTBOX_ITEMS, MOCK_FILTER_A, MOCK_BULK_ACTIONS } from '../mock_data';

describe('GeoListTopBar', () => {
  let wrapper;

  const defaultProps = {
    listboxHeaderText: 'Select item',
    activeListboxItem: MOCK_LISTBOX_ITEMS[0].value,
    activeFilteredSearchFilters: [MOCK_FILTER_A],
    showActions: true,
    bulkActions: MOCK_BULK_ACTIONS,
  };

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(GeoListTopBar, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GeoListFilteredSearchBar);
  const findBulkActions = () => wrapper.findComponent(GeoListBulkActions);

  describe('GeoListFilteredSearchBar', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with correct props', () => {
      expect(findFilteredSearch().props()).toStrictEqual({
        listboxHeaderText: 'Select item',
        activeListboxItem: MOCK_LISTBOX_ITEMS[0].value,
        activeFilteredSearchFilters: [MOCK_FILTER_A],
      });
    });

    it('handleListboxChange properly passes along the event', async () => {
      findFilteredSearch().vm.$emit('listboxChange', 'test-value');
      await nextTick();

      expect(wrapper.emitted('listboxChange')).toStrictEqual([['test-value']]);
    });

    it('handleSearch properly passes along the event', async () => {
      findFilteredSearch().vm.$emit('search', 'test-search');
      await nextTick();

      expect(wrapper.emitted('search')).toStrictEqual([['test-search']]);
    });
  });

  describe('GeoListBulkActions', () => {
    describe('when showActions is false', () => {
      beforeEach(() => {
        createComponent({ props: { showActions: false } });
      });

      it('does not render bulk actions', () => {
        expect(findBulkActions().exists()).toBe(false);
      });
    });

    describe('when showActions is true', () => {
      beforeEach(() => {
        createComponent({ props: { showActions: true } });
      });

      it('renders with correct props', () => {
        expect(findBulkActions().props('bulkActions')).toStrictEqual(MOCK_BULK_ACTIONS);
      });

      it('handleBulkAction properly passes along the event', async () => {
        findBulkActions().vm.$emit('bulkAction', 'test-action');
        await nextTick();

        expect(wrapper.emitted('bulkAction')).toStrictEqual([['test-action']]);
      });
    });
  });
});
