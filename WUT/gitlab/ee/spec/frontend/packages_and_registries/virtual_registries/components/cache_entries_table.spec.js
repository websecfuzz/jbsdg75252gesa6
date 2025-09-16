import { nextTick } from 'vue';
import { GlBadge, GlButton, GlModal, GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/cache_entries_table.vue';
import { mockCacheEntries } from '../mock_data';

describe('CacheEntriesTable', () => {
  let wrapper;

  const defaultProps = {
    cacheEntries: mockCacheEntries,
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findDeleteButton = () => wrapper.findComponent(GlButton);
  const findModal = () => wrapper.findComponent(GlModal);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findTimeAgo = () => wrapper.findComponent(TimeAgoTooltip);
  const findRelativePath = () => wrapper.findByTestId('relative-path');
  const findSize = () => wrapper.findByTestId('artifact-size');

  const createComponent = (props = {}, canDelete = true) => {
    wrapper = mountExtended(CacheEntriesTable, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        glAbilities: { destroyVirtualRegistry: canDelete },
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('displays delete button', () => {
      expect(findDeleteButton().exists()).toBe(true);
    });

    it('displays badge', () => {
      expect(findBadge().text()).toBe('application/octet-stream');
    });

    it('displays path', () => {
      expect(findRelativePath().text()).toBe('/test/bar');
    });

    it('displays time ago', () => {
      expect(findTimeAgo().props('time')).toBe('2025-05-19T14:22:23.048Z');
    });

    it('displays artifact size', () => {
      expect(findSize().text()).toBe('15 KB');
    });
  });

  describe('actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays modal on delete action', async () => {
      expect(findModal().props('visible')).toBe(false);

      await findDeleteButton().trigger('click');

      expect(findModal().props('visible')).toBe(true);
    });

    it('emits delete event with correct ID', async () => {
      expect(findModal().props('visible')).toBe(false);

      await findDeleteButton().trigger('click');

      findModal().vm.$emit('primary');

      await nextTick();

      expect(wrapper.emitted('delete')).toStrictEqual([[{ id: 'NSAvdGVzdC9iYXI=' }]]);
    });
  });

  describe('without permission', () => {
    it('does not display delete button', () => {
      createComponent({}, false);

      expect(findDeleteButton().exists()).toBe(false);
    });
  });
});
