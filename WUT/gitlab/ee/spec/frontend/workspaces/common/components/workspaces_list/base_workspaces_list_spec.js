import { shallowMount } from '@vue/test-utils';
import { GlSkeletonLoader, GlAlert } from '@gitlab/ui';

import BaseWorkspacesList from 'ee/workspaces/common/components/workspaces_list/base_workspaces_list.vue';
import WorkspaceEmptyState from 'ee/workspaces/common/components/workspaces_list/empty_state.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

const findAlert = (wrapper) => wrapper.findComponent(GlAlert);

describe('workspaces/common/components/workspaces_list/base_workspaces_list.vue', () => {
  let wrapper;

  function createWrapper(props) {
    wrapper = extendedWrapper(
      shallowMount(BaseWorkspacesList, {
        propsData: {
          empty: true,
          loading: false,
          error: null,
          newWorkspacePath: '/some-path',
          ...props,
        },
      }),
    );
  }

  describe('is loading', () => {
    beforeEach(() => {
      createWrapper({
        empty: true,
        loading: true,
      });
    });

    it('does not render empty state', () => {
      const emptyState = wrapper.findComponent(WorkspaceEmptyState);
      expect(emptyState.exists()).toBe(false);
    });
  });

  describe('is empty', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders an empty state', () => {
      const emptyState = wrapper.findComponent(WorkspaceEmptyState);
      expect(emptyState.exists()).toBe(true);
    });

    it('does not render header', () => {
      const header = wrapper.findByTestId('workspaces-list-header');
      expect(header.exists()).toBe(false);
    });

    it('does not render error', () => {
      expect(findAlert(wrapper).exists()).toBe(false);
    });
  });

  describe('is not empty', () => {
    beforeEach(() => {
      createWrapper({
        empty: false,
        loading: false,
      });
    });

    it('does not render loading state', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(false);
    });

    it('does not render empty state', () => {
      const emptyState = wrapper.findComponent(WorkspaceEmptyState);
      expect(emptyState.exists()).toBe(false);
    });

    it('renders header', () => {
      const header = wrapper.findByTestId('workspaces-list-header');
      expect(header.exists()).toBe(true);
    });

    it('does not render error', () => {
      expect(findAlert(wrapper).exists()).toBe(false);
    });
  });

  describe('on error', () => {
    const MOCK_ERROR =
      'Unable to load current workspaces. Please try again or contact an administrator.';

    beforeEach(() => {
      createWrapper({
        empty: false,
        loading: false,
        error: MOCK_ERROR,
      });
    });

    it('shows alert', () => {
      expect(findAlert(wrapper).text()).toBe(MOCK_ERROR);
    });
  });
});
