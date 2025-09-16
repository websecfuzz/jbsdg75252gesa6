import { GlSprintf } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import EpicActionsSplitButton from 'ee/related_items_tree/components/epic_issue_actions_split_button.vue';
import RelatedItemsTreeHeaderActions from 'ee/related_items_tree/components/related_items_tree_header_actions.vue';
import createDefaultStore from 'ee/related_items_tree/store';
import * as epicUtils from 'ee/related_items_tree/utils/epic_utils';

import { TYPE_EPIC, TYPE_ISSUE } from '~/issues/constants';
import { mockInitialConfig, mockParentItem, mockQueryResponse } from '../mock_data';

Vue.use(Vuex);

const createComponent = ({ slots } = {}) => {
  const store = createDefaultStore();
  const children = epicUtils.processQueryResponse(mockQueryResponse.data.group);

  store.dispatch('setInitialConfig', mockInitialConfig);
  store.dispatch('setInitialParentItem', mockParentItem);
  store.dispatch('setItemChildren', {
    parentItem: mockParentItem,
    isSubItem: false,
    children,
  });
  store.dispatch('setItemChildrenFlags', {
    isSubItem: false,
    children,
  });

  return shallowMountExtended(RelatedItemsTreeHeaderActions, {
    store,
    slots,
    stubs: {
      GlSprintf,
    },
  });
};

describe('RelatedItemsTree', () => {
  describe('RelatedItemsTreeHeader', () => {
    let wrapper;

    const findEpicsIssuesSplitButton = () => wrapper.findComponent(EpicActionsSplitButton);

    describe('epic issue actions split button', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      describe('showAddEpicForm event', () => {
        let toggleAddItemForm;

        beforeEach(() => {
          toggleAddItemForm = jest.fn();
          wrapper.vm.$store.hotUpdate({
            actions: {
              toggleAddItemForm,
            },
          });
        });

        it('dispatches toggleAddItemForm action', () => {
          findEpicsIssuesSplitButton().vm.$emit('showAddEpicForm');

          expect(toggleAddItemForm).toHaveBeenCalled();

          const payload = toggleAddItemForm.mock.calls[0][1];

          expect(payload).toEqual({
            issuableType: TYPE_EPIC,
            toggleState: true,
          });
        });
      });

      describe('showCreateEpicForm event', () => {
        let toggleCreateEpicForm;

        beforeEach(() => {
          toggleCreateEpicForm = jest.fn();
          wrapper.vm.$store.hotUpdate({
            actions: {
              toggleCreateEpicForm,
            },
          });
        });

        it('dispatches toggleCreateEpicForm action', () => {
          findEpicsIssuesSplitButton().vm.$emit('showCreateEpicForm');

          expect(toggleCreateEpicForm).toHaveBeenCalled();

          const payload =
            toggleCreateEpicForm.mock.calls[toggleCreateEpicForm.mock.calls.length - 1][1];

          expect(payload).toEqual({ toggleState: true });
        });
      });

      describe('showAddIssueForm event', () => {
        let toggleAddItemForm;
        let setItemInputValue;

        beforeEach(() => {
          toggleAddItemForm = jest.fn();
          setItemInputValue = jest.fn();
          wrapper.vm.$store.hotUpdate({
            actions: {
              toggleAddItemForm,
              setItemInputValue,
            },
          });
        });

        it('dispatches toggleAddItemForm action', () => {
          findEpicsIssuesSplitButton().vm.$emit('showAddIssueForm');

          expect(toggleAddItemForm).toHaveBeenCalled();

          const payload = toggleAddItemForm.mock.calls[0][1];

          expect(payload).toEqual({
            issuableType: TYPE_ISSUE,
            toggleState: true,
          });
        });
      });

      describe('showCreateIssueForm event', () => {
        let toggleCreateIssueForm;

        beforeEach(() => {
          toggleCreateIssueForm = jest.fn();
          wrapper.vm.$store.hotUpdate({
            actions: {
              toggleCreateIssueForm,
            },
          });
        });

        it('dispatches toggleCreateIssueForm action', () => {
          findEpicsIssuesSplitButton().vm.$emit('showCreateIssueForm');

          expect(toggleCreateIssueForm).toHaveBeenCalled();

          const payload =
            toggleCreateIssueForm.mock.calls[toggleCreateIssueForm.mock.calls.length - 1][1];

          expect(payload).toEqual({ toggleState: true });
        });
      });
    });

    describe('template', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it('renders `Add` dropdown button', () => {
        expect(findEpicsIssuesSplitButton().isVisible()).toBe(true);
      });
    });
  });
});
