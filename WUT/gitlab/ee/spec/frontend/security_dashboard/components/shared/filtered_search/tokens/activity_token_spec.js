import { GlFilteredSearchToken, GlDropdownSectionHeader, GlBadge } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ActivityToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/activity_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(VueRouter);

describe('ActivityToken', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ActivityToken.DEFAULT_VALUES, operator: '||' },
    active = false,
    stubs,
    mountFn = shallowMountExtended,
    provide,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ActivityToken, {
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
        ...provide,
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

    return ActivityToken.GROUPS.flatMap((i) => i.options)
      .map((i) => i.value)
      .filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    const findAllBadges = () => wrapper.findAllComponents(GlBadge);
    const createWrapperWithAbility = ({ resolveVulnerabilityWithAi } = {}) => {
      createWrapper({
        provide: {
          glAbilities: {
            resolveVulnerabilityWithAi,
          },
        },
      });
    };

    it('shows the label', () => {
      createWrapperWithAbility();
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['STILL_DETECTED'],
        operator: '||',
      });
      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('Still detected');
    });

    const baseOptions = [
      'All activity',
      'Still detected',
      'No longer detected',
      'Has issue',
      'Does not have issue',
      'Has merge request',
      'Does not have merge request',
      'Has a solution',
      'Does not have a solution',
    ];

    const aiOptions = [
      'Vulnerability Resolution available',
      'Vulnerability Resolution unavailable',
    ];

    const baseGroupHeaders = ['Detection', 'Issue', 'Merge Request', 'Solution available'];

    const aiGroupHeaders = ['GitLab Duo (AI)'];

    it.each`
      resolveVulnerabilityWithAi | expectedOptions
      ${true}                    | ${[...baseOptions, ...aiOptions]}
      ${false}                   | ${baseOptions}
    `(
      'shows the dropdown with correct options when resolveVulnerabilityWithAi=$resolveVulnerabilityWithAi',
      ({ resolveVulnerabilityWithAi, expectedOptions }) => {
        createWrapperWithAbility({ resolveVulnerabilityWithAi });

        const findDropdownOptions = () =>
          wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

        expect(findDropdownOptions()).toEqual(expectedOptions);
      },
    );

    it.each`
      resolveVulnerabilityWithAi | expectedGroups
      ${true}                    | ${[...baseGroupHeaders, ...aiGroupHeaders]}
      ${false}                   | ${baseGroupHeaders}
    `(
      'shows the group headers correctly resolveVulnerabilityWithAi=$resolveVulnerabilityWithAi',
      ({ resolveVulnerabilityWithAi, expectedGroups }) => {
        createWrapperWithAbility({ resolveVulnerabilityWithAi });

        const findDropdownGroupHeaders = () =>
          wrapper.findAllComponents(GlDropdownSectionHeader).wrappers.map((c) => c.text());

        expect(findDropdownGroupHeaders()).toEqual(expectedGroups);
      },
    );

    it.each`
      resolveVulnerabilityWithAi | expectedBadges
      ${true}                    | ${['check-circle-dashed', 'issues', 'merge-request', 'bulb', 'tanuki-ai']}
      ${false}                   | ${['check-circle-dashed', 'issues', 'merge-request', 'bulb']}
    `(
      'shows the correct badges when resolveVulnerabilityWithAi=$resolveVulnerabilityWithAi',
      ({ resolveVulnerabilityWithAi, expectedBadges }) => {
        createWrapperWithAbility({ resolveVulnerabilityWithAi });

        expect(findAllBadges().wrappers.map((component) => component.props('icon'))).toEqual(
          expectedBadges,
        );
      },
    );
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper({});
      await clickDropdownItem('ALL');
    });

    it('allows multiple selection of items across groups', async () => {
      await clickDropdownItem('HAS_ISSUE', 'HAS_MERGE_REQUEST');

      expect(isOptionChecked('HAS_ISSUE')).toBe(true);
      expect(isOptionChecked('HAS_MERGE_REQUEST')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('allows only one item to be selected within a group', async () => {
      await clickDropdownItem('HAS_ISSUE', 'DOES_NOT_HAVE_ISSUE');

      expect(isOptionChecked('HAS_ISSUE')).toBe(false);
      expect(isOptionChecked('DOES_NOT_HAVE_ISSUE')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All activity" when that item is selected', async () => {
      await clickDropdownItem('HAS_ISSUE', 'HAS_MERGE_REQUEST', 'ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('selects "All activity" when last selected item is deselected', async () => {
      // Select and deselect "Has issue"
      await clickDropdownItem('HAS_ISSUE', 'HAS_ISSUE');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('emits filters-changed event when a filter is selected', async () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      await clickDropdownItem('STILL_DETECTED', 'HAS_ISSUE', 'HAS_MERGE_REQUEST', 'HAS_SOLUTION');
      expect(spy).toHaveBeenCalledWith({
        hasResolution: false,
        hasIssues: true,
        hasMergeRequest: true,
        hasRemediations: true,
      });

      await clickDropdownItem(
        'NO_LONGER_DETECTED',
        'DOES_NOT_HAVE_ISSUE',
        'DOES_NOT_HAVE_MERGE_REQUEST',
        'DOES_NOT_HAVE_SOLUTION',
      );
      expect(spy).toHaveBeenCalledWith({
        hasResolution: true,
        hasIssues: false,
        hasMergeRequest: false,
        hasRemediations: false,
      });
    });
  });

  describe('on clear', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended, stubs: { QuerystringSync: false } });
      await nextTick();
    });

    it('emits filters-changed event and clears the query string', () => {
      const spy = jest.fn();
      eventHub.$on('filters-changed', spy);

      findFilteredSearchToken().vm.$emit('destroy');

      expect(spy).toHaveBeenCalledWith({
        hasResolution: undefined,
        hasIssues: undefined,
        hasMergeRequest: undefined,
        hasRemediations: undefined,
      });
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

    it('shows "Has issue" when only "Has issue" is selected', async () => {
      await clickDropdownItem('HAS_ISSUE');
      expect(findViewSlot().text()).toBe('Has issue');
    });

    it('shows "Has issue, Has merge request" when "Has issue" and another option is selected', async () => {
      await clickDropdownItem('HAS_ISSUE', 'HAS_MERGE_REQUEST');
      expect(findViewSlot().text()).toBe('Has issue, Has merge request');
    });

    it('shows "Still detected, Has issue +1 more" when more than 2 options are selected', async () => {
      await clickDropdownItem('STILL_DETECTED', 'HAS_ISSUE', 'HAS_MERGE_REQUEST');
      expect(findViewSlot().text()).toBe('Still detected, Has issue +1 more');
    });

    it('shows "All activity" when "All activity" is selected', async () => {
      await clickDropdownItem('ALL');
      expect(findViewSlot().text()).toBe('All activity');
    });
  });

  describe('QuerystringSync component', () => {
    beforeEach(() => {
      createWrapper({});
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'activity',
        defaultValues: ActivityToken.queryStringDefaultValues,
        value: ActivityToken.DEFAULT_VALUES,
        validValues: [
          'ALL',
          'STILL_DETECTED',
          'NO_LONGER_DETECTED',
          'HAS_ISSUE',
          'DOES_NOT_HAVE_ISSUE',
          'HAS_MERGE_REQUEST',
          'DOES_NOT_HAVE_MERGE_REQUEST',
          'HAS_SOLUTION',
          'DOES_NOT_HAVE_SOLUTION',
          'AI_RESOLUTION_AVAILABLE',
          'AI_RESOLUTION_UNAVAILABLE',
        ],
      });
    });

    it('receives `ALL_ACTIVITY_VALUE` when "All activity" option is clicked', async () => {
      await clickDropdownItem('ALL');

      expect(findQuerystringSync().props('value')).toEqual(['ALL']);
    });

    it.each`
      emitted                                                         | expected
      ${['HAS_ISSUE', 'HAS_MERGE_REQUEST', 'DOES_NOT_HAVE_SOLUTION']} | ${['HAS_ISSUE', 'HAS_MERGE_REQUEST', 'DOES_NOT_HAVE_SOLUTION']}
      ${['ALL']}                                                      | ${['ALL']}
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
