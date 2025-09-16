import { GlCollapsibleListbox } from '@gitlab/ui';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('BaseItemsDropdown', () => {
  let wrapper;

  const mockedItemsIds = ['1', '2', '3'];
  const mockedItems = mockedItemsIds.map((id) => ({
    id,
    value: id,
    text: `text_${id}`,
    fullPath: `fullPath_${id}`,
  }));

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(BaseItemsDropdown, {
      propsData: {
        items: [],
        ...propsData,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default rendering', () => {
    it('renders dropdown with default properties', () => {
      createComponent();

      expect(findDropdown().props('block')).toBe(true);
      expect(findDropdown().props('searchable')).toBe(true);
      expect(findDropdown().props('fluidWidth')).toBe(true);
      expect(findDropdown().props('isCheckCentered')).toBe(true);
      expect(findDropdown().props('headerText')).toBe('');
      expect(findDropdown().props('resetButtonLabel')).toBe('Clear all');

      expect(findDropdown().props('loading')).toBe(false);
      expect(findDropdown().props('searching')).toBe(false);
    });
  });

  describe('loading state', () => {
    it('renders loading and searching state', () => {
      createComponent({
        propsData: {
          loading: true,
          searching: true,
        },
      });

      expect(findDropdown().props('loading')).toBe(true);
      expect(findDropdown().props('searching')).toBe(true);
    });
  });

  describe('listbox items', () => {
    beforeEach(() => {
      createComponent({
        propsData: { items: mockedItems },
      });
    });

    it('renders listbox items', () => {
      expect(findDropdown().props('items')).toEqual(mockedItems);
    });

    it('selects items', () => {
      findDropdown().vm.$emit('select', mockedItemsIds[0]);
      expect(wrapper.emitted('select')).toEqual([[mockedItemsIds[0]]]);
    });

    it('selects all items', () => {
      findDropdown().vm.$emit('select-all');
      expect(wrapper.emitted('select-all')).toEqual([[mockedItemsIds]]);
    });

    it('renders correct default text', () => {
      expect(findDropdown().props('toggleText')).toBe('Select projects');
    });
  });

  describe('selected items', () => {
    const selected = [mockedItemsIds[0], mockedItemsIds[1]];
    it('renders selected items when ids are Strings', () => {
      createComponent({
        propsData: {
          items: mockedItems,
          selected,
        },
      });

      expect(findDropdown().props('selected')).toEqual(selected);
      expect(findDropdown().props('toggleText')).toBe('text_1, text_2');
    });

    it('renders selected items when ids are Numbers', () => {
      const selectedNumbers = selected.map(Number);
      createComponent({
        propsData: {
          items: mockedItems,
          selected: selectedNumbers,
        },
      });

      expect(findDropdown().props('selected')).toEqual(selectedNumbers);
      expect(findDropdown().props('toggleText')).toBe('text_1, text_2');
    });
  });

  describe('single item selection', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selected: mockedItemsIds[0],
          multiple: false,
        },
      });
    });

    it('does not render reset button label', () => {
      expect(findDropdown().props('resetButtonLabel')).toBe('');
    });

    it('renders selected id as array', () => {
      expect(findDropdown().props('selected')).toBe('1');
    });
  });

  describe('events', () => {
    it.each`
      event               | payload
      ${'reset'}          | ${undefined}
      ${'bottom-reached'} | ${undefined}
      ${'select-all'}     | ${mockedItemsIds}
      ${'search'}         | ${'abc'}
      ${'select'}         | ${[mockedItemsIds[0]]}
    `('emits events', ({ event, payload }) => {
      createComponent();
      findDropdown().vm.$emit(event, payload);

      expect(wrapper.emitted(event)).toHaveLength(1);
    });

    it('trims search event payload', () => {
      createComponent();
      findDropdown().vm.$emit('search', 'abc  ');

      expect(wrapper.emitted('search')).toEqual([['abc']]);
    });
  });

  describe('search', () => {
    it('renders correct text when search is performed with selected items', async () => {
      createComponent({
        propsData: {
          items: mockedItems,
          selected: [mockedItemsIds[0], mockedItemsIds[1]],
        },
      });

      expect(findDropdown().props('toggleText')).toEqual('text_1, text_2');

      await wrapper.setProps({ items: [mockedItems[2]] });
      await findDropdown().vm.$emit('search', 'text_3');

      expect(findDropdown().props('toggleText')).toEqual('text_1, text_2');
    });
  });
});
