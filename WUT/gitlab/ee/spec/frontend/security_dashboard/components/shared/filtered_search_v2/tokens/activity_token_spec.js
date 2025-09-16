import { GlFilteredSearchToken, GlDropdownSectionHeader, GlBadge } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ActivityToken, {
  GROUPS,
} from 'ee/security_dashboard/components/shared/filtered_search_v2/tokens/activity_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search_v2/components/search_suggestion.vue';
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

    return GROUPS.flatMap((i) => i.options)
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
        data: ['ALL'],
        operator: '||',
      });
      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('All activity');
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
  });

  describe('on clear', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });
      await nextTick();
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
});
