import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ReportTypeToken from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/report_type_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { ALL_ID as ALL_REPORT_TYPES_ID } from 'ee/security_dashboard/components/shared/filters/constants';

Vue.use(VueRouter);

describe('ReportTypeToken', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ['ALL'], operator: '||' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ReportTypeToken, {
      router,
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
      },
      stubs: {
        QuerystringSync: true,
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isOptionChecked = (v) => wrapper.findByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  const allOptionsExcept = (value) => {
    const exempt = Array.isArray(value) ? value : [value];

    return wrapper.vm.items.map((i) => i.value).filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['ALL'],
        operator: '||',
      });
      expect(wrapper.findByTestId('report-type-token-value').text()).toBe('All report types');
    });

    it('shows the dropdown with correct options', () => {
      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual([
        'All report types',
        'API Fuzzing',
        'Container Scanning',
        'Coverage Fuzzing',
        'DAST',
        'Dependency Scanning',
        'SAST',
        'Secret Detection',
        'Manually added',
      ]);
    });
  });

  describe('item selection - reportType', () => {
    beforeEach(async () => {
      createWrapper({ toolFilterType: 'reportType' });
      await clickDropdownItem('ALL');
    });

    it('allows multiple selection of items across groups', async () => {
      await clickDropdownItem('SAST', 'DAST');

      expect(isOptionChecked('SAST')).toBe(true);
      expect(isOptionChecked('DAST')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All report types" when that item is selected', async () => {
      await clickDropdownItem('SAST', 'DAST', 'ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      expect(isOptionChecked('ALL')).toBe(true);
    });
  });

  describe('on clear', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended, stubs: { QuerystringSync: false } });
      await nextTick();
    });

    it('resets selected values', async () => {
      findFilteredSearchToken().vm.$emit('destroy');
      await nextTick();

      expect(wrapper.vm.selectedReportTypes).toEqual([ALL_REPORT_TYPES_ID]);
    });
  });

  describe('toggle text', () => {
    const findViewSlot = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });

      // Let's set initial state as ALL. It's easier to manipulate because
      // selecting a new value should unselect this value automatically and
      // we can start from an empty state.
      await clickDropdownItem('ALL');
    });

    it('shows "All report types" when "All report types" is selected', async () => {
      await clickDropdownItem('ALL');
      expect(findViewSlot().text()).toBe('All report types');
    });

    it('shows only 1 report type when 1 option is selected', async () => {
      await clickDropdownItem('DAST');
      expect(findViewSlot().text()).toBe('DAST');
    });

    it('shows the 2 report types when 2 option is selected', async () => {
      await clickDropdownItem('DAST', 'SAST');
      expect(findViewSlot().text()).toBe('DAST, SAST');
    });

    it('shows the 2 report types with "+1" when more than 3 options are selected', async () => {
      await clickDropdownItem('DAST', 'API_FUZZING', 'SAST');
      expect(findViewSlot().text()).toBe('API Fuzzing, DAST +1 more');
    });
  });
});
