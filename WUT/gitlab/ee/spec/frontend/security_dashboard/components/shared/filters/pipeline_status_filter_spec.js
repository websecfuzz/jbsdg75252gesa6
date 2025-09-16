import { GlCollapsibleListbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import PipelineStatusFilter from 'ee/security_dashboard/components/shared/filters/pipeline_status_filter.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';

const ALL_STATUS_VALUE = 'ALL';
const OPTION_VALUES = ['ALL', 'DETECTED', 'CONFIRMED', 'DISMISSED', 'RESOLVED'];
const DEFAULT_VALUES = ['DETECTED'];

describe('Pipeline Status Filter component', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = mountExtended(PipelineStatusFilter, {
      stubs: { QuerystringSync: true },
    });
  };

  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const clickDropdownItem = async (...ids) => {
    findListbox().vm.$emit('select', [...ids]);
    await nextTick();
  };

  beforeEach(() => {
    createWrapper();
  });

  describe('QuerystringSync component', () => {
    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'state',
        value: DEFAULT_VALUES,
        validValues: ['ALL', 'DETECTED', 'CONFIRMED', 'DISMISSED', 'RESOLVED'],
      });
    });

    it('receives ALL_STATUS_VALUE when All Statuses option is clicked', async () => {
      await clickDropdownItem(ALL_STATUS_VALUE);

      expect(findQuerystringSync().props('value')).toEqual([ALL_STATUS_VALUE]);
    });

    it.each`
      emitted                      | expected
      ${['CONFIRMED', 'RESOLVED']} | ${['CONFIRMED', 'RESOLVED']}
      ${[ALL_STATUS_VALUE]}        | ${[ALL_STATUS_VALUE]}
    `('restores selected items - $emitted', async ({ emitted, expected }) => {
      findQuerystringSync().vm.$emit('input', emitted);
      await nextTick();

      expect(findListbox().props('selected')).toEqual(expected);
    });
  });

  describe('default view', () => {
    it('shows the label', () => {
      expect(wrapper.find('label').text()).toBe('Status');
    });

    it('shows the dropdown with correct header text', () => {
      expect(findListbox().props('headerText')).toBe('Status');
    });

    it('shows the placeholder correctly', async () => {
      await clickDropdownItem('CONFIRMED', 'RESOLVED');
      expect(findListbox().props('toggleText')).toBe('Confirmed +1 more');
    });
  });

  describe('dropdown items', () => {
    it('shows all dropdown items with correct text', () => {
      expect(findListbox().props('items')).toEqual([
        { text: 'All statuses', value: ALL_STATUS_VALUE },
        { text: 'Needs triage', value: 'DETECTED' },
        { text: 'Confirmed', value: 'CONFIRMED' },
        { text: 'Dismissed', value: 'DISMISSED' },
        { text: 'Resolved', value: 'RESOLVED' },
      ]);
    });

    it('toggles the item selection when clicked on', async () => {
      await clickDropdownItem('CONFIRMED', 'RESOLVED');
      expect(findListbox().props('selected')).toEqual(['CONFIRMED', 'RESOLVED']);
      await clickDropdownItem('DETECTED');
      expect(findListbox().props('selected')).toEqual(['DETECTED']);
    });

    it('selects default items when created', () => {
      expect(findListbox().props('selected')).toEqual(DEFAULT_VALUES);
    });

    describe('ALL item', () => {
      it('selects "All statuses" and deselects everything else when it is clicked', async () => {
        await clickDropdownItem(ALL_STATUS_VALUE);
        expect(findListbox().props('selected')).toEqual([ALL_STATUS_VALUE]);
      });

      it('selects "All statuses" when nothing is selected', async () => {
        await clickDropdownItem();
        expect(findListbox().props('selected')).toEqual([ALL_STATUS_VALUE]);
      });

      it('deselects the "All statuses" when another item is clicked', async () => {
        await clickDropdownItem(ALL_STATUS_VALUE, 'CONFIRMED');
        expect(findListbox().props('selected')).toEqual(['CONFIRMED']);
      });
    });
  });

  describe('filter-changed event', () => {
    it('emits filter-changed event with default values when created', () => {
      expect(wrapper.emitted('filter-changed')[0][0].state).toEqual(DEFAULT_VALUES);
    });

    it('emits filter-changed event when selected item is changed', async () => {
      await clickDropdownItem(ALL_STATUS_VALUE);

      expect(wrapper.emitted('filter-changed')[1][0]).toEqual({ state: [] });

      await clickDropdownItem(...OPTION_VALUES);

      expect(wrapper.emitted('filter-changed')[2][0].state).toEqual(
        OPTION_VALUES.filter((id) => id !== ALL_STATUS_VALUE),
      );
    });
  });
});
