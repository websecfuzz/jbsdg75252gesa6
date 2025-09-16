import { GlEmptyState } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import EEWorkItemsListApp from 'ee/work_items/pages/work_items_list_app.vue';
import {
  WORK_ITEM_TYPE_NAME_EPIC,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  OPERATORS_IS,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import { mockNamespaceCustomFieldsResponse } from 'ee_jest/vue_shared/components/filtered_search_bar/mock_data';

const skipReason = new SkipReason({
  name: 'WorkItemsListApp EE component',
  reason: 'Caught error after test environment was torn down',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/478775',
});

describeSkipVue3(skipReason, () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  Vue.use(VueApollo);

  const customFieldsQueryHandler = jest.fn().mockResolvedValue(mockNamespaceCustomFieldsResponse);

  const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);
  const findListEmptyState = () => wrapper.findComponent(EmptyStateWithAnyIssues);
  const findPageEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findWorkItemsListApp = () => wrapper.findComponent(WorkItemsListApp);

  const baseProvide = {
    groupIssuesPath: 'groups/gitlab-org/-/issues',
  };

  const mountComponent = ({
    hasEpicsFeature = true,
    showNewWorkItem = true,
    isGroup = true,
    workItemType = WORK_ITEM_TYPE_NAME_EPIC,
    props = {},
  } = {}) => {
    wrapper = shallowMountExtended(EEWorkItemsListApp, {
      apolloProvider: createMockApollo([[namespaceCustomFieldsQuery, customFieldsQueryHandler]]),
      provide: {
        hasEpicsFeature,
        hasCustomFieldsFeature: true,
        showNewWorkItem,
        isGroup,
        workItemType,
        ...baseProvide,
      },
      stubs: {
        EmptyStateWithoutAnyIssues: {
          template: '<div></div>',
        },
      },
      propsData: {
        rootPageFullPath: 'gitlab-org',
        ...props,
      },
    });
  };

  describe('create-work-item modal', () => {
    describe.each`
      hasEpicsFeature | showNewWorkItem | exists
      ${false}        | ${false}        | ${false}
      ${true}         | ${false}        | ${false}
      ${false}        | ${true}         | ${false}
      ${true}         | ${true}         | ${true}
    `(
      'when hasEpicsFeature=$hasEpicsFeature and showNewWorkItem=$showNewWorkItem',
      ({ hasEpicsFeature, showNewWorkItem, exists }) => {
        it(`${exists ? 'renders' : 'does not render'}`, () => {
          mountComponent({ hasEpicsFeature, showNewWorkItem });

          expect(findCreateWorkItemModal().exists()).toBe(exists);
        });
      },
    );

    it('passes the right props to modal when hasEpicsFeature is true', () => {
      mountComponent({ hasEpicsFeature: true, showNewWorkItem: true });

      expect(findCreateWorkItemModal().exists()).toBe(true);
      expect(findCreateWorkItemModal().props()).toMatchObject({
        isGroup: true,
        preselectedWorkItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
    });

    describe('when "workItemCreated" event is emitted', () => {
      it('increments `eeWorkItemUpdateCount` prop on WorkItemsListApp', async () => {
        mountComponent();

        expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(0);

        findCreateWorkItemModal().vm.$emit('workItemCreated');
        await nextTick();

        expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(1);
      });
    });
  });

  describe('empty states', () => {
    describe('when hasEpicsFeature=true', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: true });
      });

      it('renders list empty state', () => {
        expect(findListEmptyState().props()).toEqual({
          hasSearch: false,
          isEpic: true,
          isOpenTab: true,
        });
      });

      it('renders page empty state', () => {
        expect(wrapper.findComponent(GlEmptyState).props()).toMatchObject({
          description: 'Track groups of issues that share a theme, across projects and milestones',
          title:
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
        });
      });
    });

    describe('when hasEpicsFeature=false', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: false });
      });

      it('does not render list empty state', () => {
        expect(findListEmptyState().exists()).toBe(false);
      });

      it('does not render page empty state', () => {
        expect(findPageEmptyState().exists()).toBe(false);
      });
    });
  });

  describe('when withTabs is false', () => {
    it('passes the correct props to WorkItemsListApp', () => {
      mountComponent({ props: { withTabs: false } });

      expect(findWorkItemsListApp().props('withTabs')).toBe(false);
    });
  });

  describe('custom field filter tokens', () => {
    const mockCustomFields = mockNamespaceCustomFieldsResponse.data.namespace.customFields.nodes;
    const allowedFields = mockCustomFields.filter(
      (field) =>
        [CUSTOM_FIELDS_TYPE_SINGLE_SELECT, CUSTOM_FIELDS_TYPE_MULTI_SELECT].includes(
          field.fieldType,
        ) && field.workItemTypes.some((type) => type.name === WORK_ITEM_TYPE_NAME_EPIC),
    );

    it('fetches custom fields when component is mounted', async () => {
      mountComponent();
      await waitForPromises();

      expect(customFieldsQueryHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org',
        active: true,
      });
    });

    it('passes custom field tokens to WorkItemsListApp and unique field is based on field type', async () => {
      mountComponent();
      await waitForPromises();

      const expectedTokens = allowedFields.map((field) => ({
        type: `${TOKEN_TYPE_CUSTOM_FIELD}[${field.id.split('/').pop()}]`,
        title: field.name,
        icon: 'multiple-choice',
        field,
        fullPath: 'gitlab-org',
        token: expect.any(Function),
        operators: OPERATORS_IS,
        unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
      }));

      expect(findWorkItemsListApp().props('eeSearchTokens')).toHaveLength(2);
      expect(findWorkItemsListApp().props('eeSearchTokens')[0]).toMatchObject(expectedTokens[0]);
      expect(findWorkItemsListApp().props('eeSearchTokens')[1]).toMatchObject(expectedTokens[1]);
    });
  });
});
