import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue from 'vue';

export function parseAttributes(el) {
  const { items: itemsString, selected, placement, headerText } = el.dataset;

  const items = JSON.parse(itemsString);

  const { className } = el;

  return { items, selected, placement, className, headerText };
}

export function initListbox(el, { onChange } = {}) {
  if (!el) return null;

  const { items, selected, placement, className, headerText } = parseAttributes(el);

  return new Vue({
    el,
    data() {
      return {
        selected,
      };
    },
    computed: {
      text() {
        return items.find(({ value }) => value === this.selected)?.text;
      },
    },
    render(h) {
      return h(GlCollapsibleListbox, {
        props: {
          items,
          placement,
          selected: this.selected,
          toggleText: this.text,
          headerText,
        },
        class: className,
        on: {
          select: (selectedValue) => {
            this.selected = selectedValue;
            const selectedItem = items.find(({ value }) => value === selectedValue);

            if (typeof onChange === 'function') {
              onChange(selectedItem);
            }
          },
        },
      });
    },
  });
}
