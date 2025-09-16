import { shallowMount } from '@vue/test-utils';
import { assertProps } from 'helpers/assert_props';

import SlotSwitch from 'ee/related_items_tree/components/slot_switch.vue';

describe('SlotSwitch', () => {
  const slots = {
    first: '<a data-testid="slot-item">AGP</a>',
    second: '<p data-testid="slot-item">PCI</p>',
  };

  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMount(SlotSwitch, {
      propsData,
      slots,
    });
  };

  const getChildrenHtml = () =>
    wrapper.findAll('[data-testid="slot-item"]').wrappers.map((c) => c.html());

  it('throws an error if activeSlotNames is missing', () => {
    expect(() => assertProps(SlotSwitch, {})).toThrow(
      '[Vue warn]: Missing required prop: "activeSlotNames"',
    );
  });

  it('renders no slots if activeSlotNames is empty', () => {
    createComponent({
      activeSlotNames: [],
    });

    expect(getChildrenHtml()).toHaveLength(0);
  });

  it('renders one slot if activeSlotNames contains single slot name', () => {
    createComponent({
      activeSlotNames: ['first'],
    });

    expect(getChildrenHtml()).toEqual([slots.first]);
  });

  it('renders multiple slots if activeSlotNames contains multiple slot names', () => {
    createComponent({
      activeSlotNames: Object.keys(slots),
    });

    expect(getChildrenHtml()).toEqual(Object.values(slots));
  });
});
