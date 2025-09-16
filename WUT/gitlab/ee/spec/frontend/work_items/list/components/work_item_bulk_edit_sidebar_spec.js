import { GlForm } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import workItemBulkUpdateMutation from '~/work_items/graphql/list/work_item_bulk_update.mutation.graphql';
import workItemParentQuery from '~/work_items/graphql/list//work_item_parent.query.graphql';
import WorkItemBulkEditSidebar from '~/work_items/components/work_item_bulk_edit/work_item_bulk_edit_sidebar.vue';
import WorkItemBulkEditIteration from 'ee_component/work_items/components/list/work_item_bulk_edit_iteration.vue';
import { workItemParentQueryResponse } from '../../mock_data';

Vue.use(VueApollo);

describe('WorkItemBulkEditSidebar component EE', () => {
  let wrapper;

  const checkedItems = [
    { id: 'gid://gitlab/WorkItem/11', title: 'Work Item 11' },
    { id: 'gid://gitlab/WorkItem/22', title: 'Work Item 22' },
  ];

  const workItemParentQueryHandler = jest.fn().mockResolvedValue(workItemParentQueryResponse);
  const workItemBulkUpdateHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemBulkUpdate: { updatedWorkItemCount: 1 } } });

  const createComponent = ({
    provide = {},
    props = {},
    mutationHandler = workItemBulkUpdateHandler,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemBulkEditSidebar, {
      apolloProvider: createMockApollo([
        [workItemParentQuery, workItemParentQueryHandler],
        [workItemBulkUpdateMutation, mutationHandler],
      ]),
      provide: {
        hasIssuableHealthStatusFeature: true,
        hasIterationsFeature: true,
        ...provide,
      },
      propsData: {
        checkedItems,
        fullPath: 'group/project',
        isGroup: false,
        ...props,
      },
      stubs: {
        WorkItemBulkEditIteration: stubComponent(WorkItemBulkEditIteration),
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findIterationComponent = () => wrapper.findComponent(WorkItemBulkEditIteration);

  describe('when work_items_bulk_edit is enabled', () => {
    it('calls mutation to bulk edit ee attributes', async () => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList: false },
      });
      await waitForPromises();

      findIterationComponent().vm.$emit('input', 'gid://gitlab/Iteration/1215');
      findForm().vm.$emit('submit', { preventDefault: () => {} });

      expect(workItemBulkUpdateHandler).toHaveBeenCalledWith({
        input: {
          parentId: 'gid://gitlab/Group/1',
          ids: ['gid://gitlab/WorkItem/11', 'gid://gitlab/WorkItem/22'],
          iterationWidget: {
            iterationId: 'gid://gitlab/Iteration/1215',
          },
        },
      });
    });
  });

  describe('"Iteration" component', () => {
    it.each([true, false])('renders depending on isEpicsList prop', (isEpicsList) => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList },
      });

      expect(findIterationComponent().exists()).toBe(!isEpicsList);
    });

    it('updates iteration when "Iteration" component emits "input" event', async () => {
      createComponent({
        provide: {
          glFeatures: {
            workItemsBulkEdit: true,
          },
        },
        props: { isEpicsList: false },
      });

      findIterationComponent().vm.$emit('input', 'gid://gitlab/Iteration/1215');
      await nextTick();

      expect(findIterationComponent().props('value')).toBe('gid://gitlab/Iteration/1215');
    });
  });
});
