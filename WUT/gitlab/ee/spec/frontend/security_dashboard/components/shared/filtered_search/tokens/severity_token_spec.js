import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import SeverityToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/severity_token.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(VueRouter);

describe('Severity Token component', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_IS,
  };

  const createWrapper = ({
    value = {},
    active = false,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(SeverityToken, {
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
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
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

    return SeverityToken.items.map((i) => i.value).filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({ data: ['ALL'] });
      expect(wrapper.findByTestId('severity-token-placeholder').text()).toBe('All severities');
    });

    it('shows the dropdown with correct options', () => {
      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual([
        'All severities',
        'Critical',
        'High',
        'Medium',
        'Low',
        'Info',
        'Unknown',
      ]);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper({});
      await clickDropdownItem('ALL');
    });

    it('toggles the item selection when clicked on', async () => {
      await clickDropdownItem('CRITICAL', 'HIGH');

      expect(isOptionChecked('ALL')).toBe(false);
      expect(isOptionChecked('CRITICAL')).toBe(true);
      expect(isOptionChecked('HIGH')).toBe(true);

      // Select All items
      await clickDropdownItem('ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      // Select low
      await clickDropdownItem('LOW');

      expect(isOptionChecked('LOW')).toBe(true);
      allOptionsExcept('LOW').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      // Unselecting low should select all items once again
      await clickDropdownItem('LOW');

      expect(isOptionChecked('ALL')).toBe(true);
      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      // Select 2 states
      await clickDropdownItem('MEDIUM', 'HIGH');

      expect(spy).toHaveBeenCalledWith({
        severity: ['MEDIUM', 'HIGH'],
      });
    });
  });

  describe('toggle text', () => {
    const findSlotView = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(async () => {
      createWrapper({ value: {}, mountFn: mountExtended });

      // Let's set initial state as ALL. It's easier to manipulate because
      // selecting a new value should unselect this value automatically and
      // we can start from an empty state.
      await clickDropdownItem('ALL');
    });

    it('shows "All severities" when "All severities" option is selected', async () => {
      await clickDropdownItem('ALL');
      expect(findSlotView().text()).toBe('All severities');
    });

    it('shows "Critical, High" when critical and high severities are selected', async () => {
      await clickDropdownItem('CRITICAL', 'HIGH');
      expect(findSlotView().text()).toBe('Critical, High');
    });

    it('shows "Critical, High +1 more" when more than 2 options are selected', async () => {
      await clickDropdownItem('CRITICAL', 'HIGH', 'LOW');
      expect(findSlotView().text()).toBe('Critical, High +1 more');
    });

    it('shows "Low" when only low severity is selected', async () => {
      await clickDropdownItem('LOW');
      expect(findSlotView().text()).toBe('Low');
    });
  });

  describe('QuerystringSync component', () => {
    beforeEach(() => {
      createWrapper({});
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'severity',
        value: ['ALL'],
        validValues: SeverityToken.VALID_IDS,
      });
    });

    it('receives ALL_STATUS_VALUE when All Statuses option is clicked', async () => {
      await clickDropdownItem('ALL');

      expect(findQuerystringSync().props('value')).toEqual(['ALL']);
    });

    it.each`
      emitted                   | expected
      ${['CRITICAL', 'MEDIUM']} | ${['CRITICAL', 'MEDIUM']}
      ${['ALL']}                | ${['ALL']}
    `('restores selected items from the query string - $emitted', async ({ emitted, expected }) => {
      findQuerystringSync().vm.$emit('input', emitted);
      await nextTick();

      expected.forEach((item) => {
        expect(isOptionChecked(item)).toBe(true);
      });

      allOptionsExcept(expected).forEach((item) => {
        expect(isOptionChecked(item)).toBe(false);
      });
    });
  });
});
