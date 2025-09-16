import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import StatusToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/status_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(VueRouter);

describe('Status Token component', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_IS,
  };

  const createWrapper = ({
    value = { data: StatusToken.DEFAULT_VALUES, operator: '=' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(StatusToken, {
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

    return StatusToken.GROUPS.flatMap((i) => i.options)
      .map((i) => i.value)
      .filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    const findDropdownOptions = () =>
      wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.props('text'));

    beforeEach(() => {
      createWrapper();
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['DETECTED', 'CONFIRMED'],
        operator: '=',
      });
      expect(wrapper.findByTestId('status-token-placeholder').text()).toBe(
        'Needs triage, Confirmed',
      );
    });

    it('shows the dropdown with correct options', () => {
      expect(findDropdownOptions()).toEqual([
        'All statuses',
        'Needs triage',
        'Confirmed',
        'Resolved',
        'All dismissal reasons',
        'Acceptable risk',
        'False positive',
        'Mitigating control',
        'Used in tests',
        'Not applicable',
      ]);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper({});
      await clickDropdownItem('ALL');
    });

    it('toggles the item selection when clicked on', async () => {
      await clickDropdownItem('CONFIRMED', 'RESOLVED');

      expect(isOptionChecked('ALL')).toBe(false);
      expect(isOptionChecked('CONFIRMED')).toBe(true);
      expect(isOptionChecked('RESOLVED')).toBe(true);

      // Add a dismissal reason
      await clickDropdownItem('ACCEPTABLE_RISK');

      expect(isOptionChecked('CONFIRMED')).toBe(true);
      expect(isOptionChecked('RESOLVED')).toBe(true);
      expect(isOptionChecked('ACCEPTABLE_RISK')).toBe(true);
      expect(isOptionChecked('DISMISSED')).toBe(false);

      // Select all
      await clickDropdownItem('ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      // Select All Dismissed Values
      await clickDropdownItem('DISMISSED');

      allOptionsExcept('DISMISSED').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      // Selecting another dismissed should unselect All Dismissed values
      await clickDropdownItem('USED_IN_TESTS');

      expect(isOptionChecked('USED_IN_TESTS')).toBe(true);
      expect(isOptionChecked('DISMISSED')).toBe(false);
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      // Select 2 states
      await clickDropdownItem('CONFIRMED', 'RESOLVED');
      expect(spy).toHaveBeenCalledWith({ dismissalReason: [], state: ['CONFIRMED', 'RESOLVED'] });

      // Select a dismissal reason. It should not unselect the previous states.
      await clickDropdownItem('ACCEPTABLE_RISK');

      expect(spy).toHaveBeenCalledWith({
        dismissalReason: ['ACCEPTABLE_RISK'],
        state: ['CONFIRMED', 'RESOLVED'],
      });
    });
  });

  describe('on clear', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended, stubs: { QuerystringSync: false } });
      await nextTick();
    });

    it('resetting emits filters-changed event and clears the query string', () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      findFilteredSearchToken().vm.$emit('destroy');

      expect(spy).toHaveBeenCalledWith({ dismissalReason: [], state: [] });
    });
  });

  describe('toggle text', () => {
    const findSlotView = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });

      // Let's set initial state as ALL. It's easier to manipulate because
      // selecting a new value should unselect this value automatically and
      // we can start from an empty state.
      await clickDropdownItem('ALL');
    });

    it('shows "Dismissed (all reasons)" when only "All dismissal reasons" option is selected', async () => {
      await clickDropdownItem('DISMISSED');
      expect(findSlotView().text()).toBe('Dismissed (all reasons)');
    });

    it('shows "Dismissed (2 reasons)" when only 2 dismissal reasons are selected', async () => {
      await clickDropdownItem('FALSE_POSITIVE', 'ACCEPTABLE_RISK');
      expect(findSlotView().text()).toBe('Dismissed (2 reasons)');
    });

    it('shows "Confirmed, False positive" when confirmed and a dismissal reason are selected', async () => {
      await clickDropdownItem('CONFIRMED', 'FALSE_POSITIVE');
      expect(findSlotView().text()).toBe('Confirmed, False positive');
    });

    it('shows "Needs triage, Confirmed +1 more" when more than 2 options are selected', async () => {
      await clickDropdownItem('CONFIRMED', 'DETECTED', 'DISMISSED');
      expect(findSlotView().text()).toBe('Needs triage, Confirmed +1 more');
    });
  });

  describe('QuerystringSync component', () => {
    beforeEach(() => {
      createWrapper({});
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'state',
        value: StatusToken.DEFAULT_VALUES,
        defaultValues: ['ALL'],
        validValues: [
          'ALL',
          'DETECTED',
          'CONFIRMED',
          'RESOLVED',
          'DISMISSED',
          'ACCEPTABLE_RISK',
          'FALSE_POSITIVE',
          'MITIGATING_CONTROL',
          'USED_IN_TESTS',
          'NOT_APPLICABLE',
        ],
      });
    });

    it('receives ALL_STATUS_VALUE when All Statuses option is clicked', async () => {
      await clickDropdownItem('ALL');

      expect(findQuerystringSync().props('value')).toEqual(['ALL']);
    });

    it.each`
      emitted                      | expected
      ${['CONFIRMED', 'RESOLVED']} | ${['CONFIRMED', 'RESOLVED']}
      ${['ALL']}                   | ${['ALL']}
    `('restores selected items - $emitted', async ({ emitted, expected }) => {
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
