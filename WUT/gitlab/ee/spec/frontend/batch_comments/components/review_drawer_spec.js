import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ReviewDrawer from '~/batch_comments/components/review_drawer.vue';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';
import { useBatchComments } from '~/batch_comments/store';
import userCanApproveQuery from '~/batch_comments/queries/can_approve.query.graphql';

jest.mock('~/autosave');
jest.mock('~/vue_shared/components/markdown/eventhub');

Vue.use(PiniaVuePlugin);
Vue.use(Vuex);
Vue.use(VueApollo);

describe('ReviewDrawer', () => {
  let wrapper;
  let pinia;
  let getCurrentUserLastNote;

  const findPlaceholderField = () => wrapper.findByTestId('placeholder-input-field');

  const createComponent = ({ canApprove = true, requirePasswordToApprove = false } = {}) => {
    getCurrentUserLastNote = Vue.observable({ id: 1 });

    const store = new Vuex.Store({
      getters: {
        getNotesData: () => ({
          markdownDocsPath: '/markdown/docs',
          quickActionsDocsPath: '/quickactions/docs',
        }),
        getNoteableData: () => ({
          id: 1,
          preview_note_path: '/preview',
          require_password_to_approve: requirePasswordToApprove,
        }),
        noteableType: () => 'merge_request',
        getCurrentUserLastNote: () => getCurrentUserLastNote,
        getDiscussion: () => jest.fn(),
      },
      modules: {
        diffs: {
          namespaced: true,
          state: {
            projectPath: 'gitlab-org/gitlab',
          },
        },
      },
    });
    const requestHandlers = [
      [
        userCanApproveQuery,
        () =>
          Promise.resolve({
            data: {
              project: {
                id: 1,
                mergeRequest: {
                  id: 1,
                  userPermissions: {
                    canApprove,
                  },
                },
              },
            },
          }),
      ],
    ];
    const apolloProvider = createMockApollo(requestHandlers);

    wrapper = mountExtended(ReviewDrawer, { pinia, store, apolloProvider });
  };

  beforeEach(() => {
    pinia = createTestingPinia({
      plugins: [globalAccessorPlugin],
    });
    useLegacyDiffs();
    useNotes();
    useBatchComments();
  });

  it.each`
    requirePasswordToApprove | exists   | existsText
    ${true}                  | ${true}  | ${'shows'}
    ${false}                 | ${false} | ${'hides'}
  `(
    '$existsText approve password if require_password_to_approve is $requirePasswordToApprove',
    async ({ requirePasswordToApprove, exists }) => {
      useBatchComments().drawerOpened = true;

      createComponent({ requirePasswordToApprove });

      await findPlaceholderField().vm.$emit('focus');

      await waitForPromises();

      expect(wrapper.findByTestId('approve_password').exists()).toBe(exists);
    },
  );
});
