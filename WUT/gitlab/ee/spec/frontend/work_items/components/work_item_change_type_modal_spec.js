import { GlModal, GlFormSelect } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';

import WorkItemChangeTypeModal from 'ee_else_ce/work_items/components/work_item_change_type_modal.vue';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import getWorkItemDesignListQuery from '~/work_items/components/design_management/graphql/design_collection.query.graphql';
import promoteToEpicMutation from '~/issues/show/queries/promote_to_epic.mutation.graphql';
import {
  WORK_ITEM_TYPE_NAME_TASK,
  WORK_ITEM_WIDGETS_NAME_MAP,
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_ISSUE,
  WORK_ITEM_TYPE_NAME_KEY_RESULT,
} from '~/work_items/constants';

import {
  namespaceWorkItemTypesWithOKRsQueryResponse,
  namespaceWorkItemTypesQueryResponse,
  workItemChangeTypeWidgets,
  promoteToEpicMutationResponse,
  namespaceWorkItemsWithoutEpicSupport,
} from '../mock_data';

describe('WorkItemChangeTypeModal component', () => {
  Vue.use(VueApollo);

  let wrapper;
  const graphqlError = 'GraphQL error';
  const keyResultTypeId =
    namespaceWorkItemTypesQueryResponse.data.workspace.workItemTypes.nodes.find(
      (item) => item.name === WORK_ITEM_TYPE_NAME_KEY_RESULT,
    ).id;

  const issueTypeId = namespaceWorkItemTypesQueryResponse.data.workspace.workItemTypes.nodes.find(
    (item) => item.name === WORK_ITEM_TYPE_NAME_ISSUE,
  ).id;

  const epicTypeId = namespaceWorkItemTypesQueryResponse.data.workspace.workItemTypes.nodes.find(
    (item) => item.name === WORK_ITEM_TYPE_NAME_EPIC,
  ).id;

  const namespaceWorkItemTypesQuerySuccessHandler = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemTypesQueryResponse);
  const namespaceWorkItemTypesWithOKRsQuerySuccessHandler = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemTypesWithOKRsQueryResponse);
  const namespaceWorkItemTypesWithoutEpicQuerySuccessHandler = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemsWithoutEpicSupport);
  const noDesignQueryHandler = jest.fn().mockResolvedValue({
    data: {
      workItem: {
        id: 'gid://gitlab/WorkItem/1',
        workItemType: {
          id: 'gid://gitlab/WorkItems::Type/1',
          name: 'Issue',
          __typename: 'WorkItemType',
        },
        widgets: [
          {
            __typename: 'WorkItemWidgetDesigns',
            type: 'DESIGNS',
            designCollection: {
              copyState: 'READY',
              designs: { nodes: [] },
              versions: { nodes: [] },
            },
          },
        ],
      },
    },
  });

  const promoteToEpicMutationSuccessHandler = jest
    .fn()
    .mockResolvedValue(promoteToEpicMutationResponse);

  const promoteToEpicMutationErrorResponse = {
    errors: [
      {
        message: graphqlError,
      },
    ],
    data: {
      promoteToEpic: null,
    },
  };

  const createComponent = ({
    widgets = [],
    workItemType = WORK_ITEM_TYPE_NAME_TASK,
    promoteToEpicMutationHandler = promoteToEpicMutationSuccessHandler,
    typesQuerySuccessHandler = namespaceWorkItemTypesQuerySuccessHandler,
  } = {}) => {
    wrapper = mountExtended(WorkItemChangeTypeModal, {
      apolloProvider: createMockApollo([
        [namespaceWorkItemTypesQuery, typesQuerySuccessHandler],
        [getWorkItemDesignListQuery, noDesignQueryHandler],
        [promoteToEpicMutation, promoteToEpicMutationHandler],
      ]),
      propsData: {
        workItemId: 'gid://gitlab/WorkItem/1',
        fullPath: 'gitlab-org/gitlab-test',
        hasParent: false,
        hasChildren: false,
        widgets,
        workItemType,
        workItemIid: '1',
        getEpicWidgetDefinitions: typesQuerySuccessHandler,
      },
      provide: {
        hasSubepicsFeature: false,
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
        }),
      },
    });
  };

  const findChangeTypeModal = () => wrapper.findComponent(GlModal);
  const findGlFormSelect = () => wrapper.findComponent(GlFormSelect);
  const findWarningAlert = () => wrapper.findByTestId('change-type-warning-message');
  const findEpicTypeOption = () => findGlFormSelect().findAll('option').at(2);

  it('renders epic type as an option when work item type is an issue', async () => {
    createComponent({ workItemType: WORK_ITEM_TYPE_NAME_ISSUE });

    await waitForPromises();

    expect(findGlFormSelect().findAll('option')).toHaveLength(3);
    expect(findEpicTypeOption().text()).toBe('Epic (Promote to group)');
  });

  it('does not render epic type as an option when it is not supported', async () => {
    createComponent({
      workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      typesQuerySuccessHandler: namespaceWorkItemTypesWithoutEpicQuerySuccessHandler,
    });

    await waitForPromises();

    expect(findGlFormSelect().findAll('option')).toHaveLength(2);
  });

  it('renders objective and key result types as select options', async () => {
    createComponent({
      workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      typesQuerySuccessHandler: namespaceWorkItemTypesWithOKRsQuerySuccessHandler,
    });

    await waitForPromises();

    expect(findGlFormSelect().findAll('option')).toHaveLength(5);
  });

  describe('when widget data has difference', () => {
    // These are possible use cases of conflicts among issues EE widgets
    // Other widgets are shared between all the work item types
    it.each`
      widgetType                              | widgetData                             | workItemType                 | typeTobeConverted | expectedString
      ${WORK_ITEM_WIDGETS_NAME_MAP.ITERATION} | ${workItemChangeTypeWidgets.ITERATION} | ${WORK_ITEM_TYPE_NAME_ISSUE} | ${epicTypeId}     | ${'Iteration'}
      ${WORK_ITEM_WIDGETS_NAME_MAP.WEIGHT}    | ${workItemChangeTypeWidgets.WEIGHT}    | ${WORK_ITEM_TYPE_NAME_ISSUE} | ${epicTypeId}     | ${'Weight'}
    `(
      'shows warning message in case of $widgetType widget',
      async ({ workItemType, widgetData, typeTobeConverted, expectedString }) => {
        createComponent({
          workItemType,
          widgets: [widgetData],
        });

        await waitForPromises();

        findGlFormSelect().vm.$emit('change', typeTobeConverted);

        await nextTick();

        expect(findWarningAlert().text()).toContain(expectedString);
        expect(findChangeTypeModal().props('actionPrimary').attributes.disabled).toBe(false);
      },
    );
  });

  describe('promote issue to epic', () => {
    it('successfully changes a work item type when conditions are met', async () => {
      createComponent({ workItemType: WORK_ITEM_TYPE_NAME_ISSUE });

      await waitForPromises();

      findGlFormSelect().vm.$emit('change', epicTypeId);

      await nextTick();

      findChangeTypeModal().vm.$emit('primary');

      await waitForPromises();

      expect(promoteToEpicMutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          iid: '1',
          projectPath: 'gitlab-org/gitlab-test',
        },
      });
    });

    it.each`
      errorType          | expectedErrorMessage | failureHandler
      ${'graphql error'} | ${graphqlError}      | ${jest.fn().mockResolvedValue(promoteToEpicMutationErrorResponse)}
      ${'network error'} | ${'Network error'}   | ${jest.fn().mockRejectedValue(new Error('Network error'))}
    `(
      'emits an error when there is a $errorType',
      async ({ expectedErrorMessage, failureHandler }) => {
        createComponent({
          workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
          promoteToEpicMutationHandler: failureHandler,
        });

        await waitForPromises();

        findGlFormSelect().vm.$emit('change', epicTypeId);

        await nextTick();

        findChangeTypeModal().vm.$emit('primary');

        await waitForPromises();

        expect(wrapper.emitted('error')[0][0]).toEqual(expectedErrorMessage);
      },
    );
  });

  describe('when okrs are enabled', () => {
    // These are possible use cases of conflicts among OKR widgets
    it.each`
      widgetType                              | widgetData                             | workItemType                      | typeTobeConverted  | expectedString
      ${WORK_ITEM_WIDGETS_NAME_MAP.MILESTONE} | ${workItemChangeTypeWidgets.MILESTONE} | ${WORK_ITEM_TYPE_NAME_ISSUE}      | ${keyResultTypeId} | ${'Milestone'}
      ${WORK_ITEM_WIDGETS_NAME_MAP.PROGRESS}  | ${workItemChangeTypeWidgets.PROGRESS}  | ${WORK_ITEM_TYPE_NAME_KEY_RESULT} | ${issueTypeId}     | ${'Progress'}
    `(
      'shows warning message in case of $widgetType widget',
      async ({ workItemType, widgetData, typeTobeConverted, expectedString }) => {
        createComponent({
          workItemType,
          widgets: [widgetData],
          typesQuerySuccessHandler: namespaceWorkItemTypesWithOKRsQuerySuccessHandler,
        });

        await waitForPromises();

        findGlFormSelect().vm.$emit('change', typeTobeConverted);

        await nextTick();

        expect(findWarningAlert().text()).toContain(expectedString);
        expect(findChangeTypeModal().props('actionPrimary').attributes.disabled).toBe(false);
      },
    );
  });
});
