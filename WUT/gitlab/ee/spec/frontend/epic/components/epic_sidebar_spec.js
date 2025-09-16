import { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EpicSidebar from 'ee/epic/components/epic_sidebar.vue';
import { getStoreConfig } from 'ee/epic/store';

import SidebarAncestorsWidget from 'ee_component/sidebar/components/ancestors_tree/sidebar_ancestors_widget.vue';

import LabelsSelectWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import SidebarParticipantsWidget from '~/sidebar/components/participants/sidebar_participants_widget.vue';
import SidebarTodoWidget from '~/sidebar/components/todo_toggle/sidebar_todo_widget.vue';
import { newDate } from '~/lib/utils/datetime_utility';

import { mockEpicMeta, mockEpicData } from '../mock_data';

describe('EpicSidebarComponent', () => {
  let wrapper;
  let store;

  const createComponent = ({ actions: actionMocks } = {}) => {
    const { actions, state, ...storeConfig } = getStoreConfig();
    store = new Vuex.Store({
      ...storeConfig,
      state: {
        ...state,
        ...mockEpicMeta,
        ...mockEpicData,
      },

      actions: { ...actions, ...actionMocks },
    });

    return shallowMountExtended(EpicSidebar, {
      store,
      provide: {
        iid: '1',
      },
    });
  };

  const findStartDateEl = () => wrapper.findByTestId('start-date');
  const findDueDateEl = () => wrapper.findByTestId('due-date');

  describe('template', () => {
    beforeEach(() => {
      gon.current_user_id = 1;

      wrapper = createComponent();
    });

    it('renders component container element with classes `right-sidebar-expanded`, `right-sidebar` & `epic-sidebar`', async () => {
      store.dispatch('toggleSidebarFlag', false);

      await nextTick();

      expect(wrapper.classes()).toContain('right-sidebar-expanded');
      expect(wrapper.classes()).toContain('right-sidebar');
      expect(wrapper.classes()).toContain('epic-sidebar');
    });

    it('renders header container element with classes `issuable-sidebar` & `js-issuable-update`', () => {
      expect(wrapper.find('.issuable-sidebar.js-issuable-update').exists()).toBe(true);
    });

    it('renders Start date & Due date elements when sidebar is expanded', async () => {
      store.dispatch('toggleSidebarFlag', false);

      await nextTick();

      expect(findStartDateEl().exists()).toBe(true);
      expect(findStartDateEl().props()).toMatchObject({
        iid: '1',
        fullPath: 'frontend-fixtures-group',
        issuableType: 'epic',
        dateType: 'startDate',
        canInherit: true,
      });

      expect(findDueDateEl().exists()).toBe(true);
      expect(findDueDateEl().props()).toMatchObject({
        iid: '1',
        fullPath: 'frontend-fixtures-group',
        issuableType: 'epic',
        dateType: 'dueDate',
        canInherit: true,
      });
    });

    it('renders labels select element', () => {
      expect(wrapper.findComponent(LabelsSelectWidget).exists()).toBe(true);
    });

    it('renders SidebarTodoWidget when user is signed in', () => {
      const todoWidget = wrapper.findComponent(SidebarTodoWidget);
      expect(todoWidget.exists()).toBe(true);
      expect(todoWidget.props()).toMatchObject({
        issuableId: `gid://gitlab/Epic/${mockEpicMeta.epicId}`,
        issuableIid: '1',
        fullPath: 'frontend-fixtures-group',
        issuableType: 'epic',
      });
    });

    describe('when sub-epics feature is not available', () => {
      it('does not renders ancestors list', async () => {
        store.dispatch('setEpicMeta', {
          ...mockEpicMeta,
          allowSubEpics: false,
        });

        await nextTick();

        expect(wrapper.findComponent(SidebarAncestorsWidget).exists()).toBe(false);
      });
    });

    describe('when sub-epics feature is available', () => {
      it('renders ancestors list', () => {
        expect(wrapper.findComponent(SidebarAncestorsWidget).exists()).toBe(true);
      });
    });

    it('renders participants widget', () => {
      expect(wrapper.findComponent(SidebarParticipantsWidget).exists()).toBe(true);
    });
  });

  describe('when user is not signed in', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('does not render SidebarTodoWidget', () => {
      expect(wrapper.findComponent(SidebarTodoWidget).exists()).toBe(false);
    });
  });

  describe('mounted', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('makes request to get epic details', () => {
      const actionSpies = {
        fetchEpicDetails: jest.fn(),
      };

      const wrapperWithMethod = createComponent({
        actions: actionSpies,
      });

      expect(actionSpies.fetchEpicDetails).toHaveBeenCalled();

      wrapperWithMethod.destroy();
    });
  });

  describe('sidebardatewidget dates', () => {
    const mockDate = '2023-03-01';

    beforeEach(() => {
      wrapper = createComponent();
    });

    it('sets min date when start date is selected', async () => {
      await findStartDateEl().vm.$emit('startDateUpdated', mockDate);

      expect(findDueDateEl().props('minDate')).toStrictEqual(newDate(mockDate));
    });

    it('sets max date when due date is selected', async () => {
      await findDueDateEl().vm.$emit('dueDateUpdated', mockDate);

      expect(findStartDateEl().props('maxDate')).toStrictEqual(newDate(mockDate));
    });
  });
});
