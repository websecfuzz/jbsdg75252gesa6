import Vue from 'vue';
import { mount } from '@vue/test-utils';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import DuoCodeReviewSystemNote from 'ee/vue_shared/components/notes/duo_code_review_system_note.vue';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useNotes } from '~/notes/store/legacy_notes';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';

Vue.use(PiniaVuePlugin);

describe('Duo code review system note component', () => {
  let pinia;
  let vm;

  function createComponent(propsData = {}) {
    useNotes().setTargetNoteHash(`note_${propsData.note.id}`);

    vm = mount(DuoCodeReviewSystemNote, {
      pinia,
      propsData,
    });
  }

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin], stubActions: false });
    useLegacyDiffs();
    useNotes();
    createComponent({
      note: {
        id: '1424',
        author: {
          id: 1,
          name: 'Root',
          username: 'root',
          state: 'active',
          avatar_url: 'path',
          path: '/root',
          user_type: 'duo_code_review_bot',
        },
        note_html: '<p dir="auto">closed</p>',
        created_at: '2017-08-02T10:51:58.559Z',
      },
    });
  });

  it('renders loading icon', () => {
    expect(vm.find('[data-testid="duo-loading-icon"]').exists()).toBe(true);
  });

  it('renders avatar', () => {
    expect(vm.find('[data-testid="system-note-avatar"]').exists()).toBe(true);
  });
});
