import { GlFormInput } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemWeight from 'ee/work_items/components/work_item_weight.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { TRACKING_CATEGORY_SHOW } from '~/work_items/constants';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import { ENTER_KEY, ESC_KEY } from '~/lib/utils/keys';
import { updateWorkItemMutationResponse } from '../mock_data';

describe('WorkItemWeight component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemId = 'gid://gitlab/WorkItem/1';

  const findHeader = () => wrapper.find('h3');
  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findApplyButton = () => wrapper.findByTestId('apply-button');
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findClearButton = () => wrapper.findByTestId('remove-weight');

  const createComponent = ({
    canUpdate = true,
    hasIssueWeightsFeature = true,
    isEditing = false,
    weight = null,
    editable = true,
    mutationHandler = jest.fn().mockResolvedValue(updateWorkItemMutationResponse),
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemWeight, {
      apolloProvider: createMockApollo([[updateWorkItemMutation, mutationHandler]]),
      propsData: {
        canUpdate,
        fullPath: 'gitlab-org/gitlab',
        widget: {
          weight,
          widgetDefinition: { editable },
        },
        workItemId,
        workItemType: 'Task',
      },
      provide: {
        hasIssueWeightsFeature,
      },
      stubs: {
        WorkItemSidebarWidget,
      },
    });

    if (isEditing) {
      findEditButton().vm.$emit('click');
    }
  };

  describe('rendering widget', () => {
    it('renders nothing if license not available', async () => {
      createComponent({ hasIssueWeightsFeature: false });
      await nextTick();

      expect(findHeader().exists()).toBe(false);
    });

    // 'editable' property means if it's available for that work item type
    it('renders nothing if not editable', async () => {
      createComponent({ editable: false });
      await nextTick();

      expect(findHeader().exists()).toBe(false);
    });
  });

  describe('value', () => {
    it('shows None when no weight is set', () => {
      createComponent();

      expect(wrapper.text()).toContain('None');
    });

    it('shows weight when weight is set', () => {
      createComponent({ weight: 4 });

      expect(wrapper.text()).not.toContain('None');
      expect(wrapper.text()).toContain('4');
    });
  });

  describe('weight input', () => {
    it('is not shown while not editing', async () => {
      createComponent();
      await nextTick();

      expect(findInput().exists()).toBe(false);
    });

    it('renders when editing', async () => {
      createComponent({ isEditing: true });
      await nextTick();

      expect(findInput().attributes()).toMatchObject({
        min: '0',
        type: 'number',
      });
    });

    it('clear button triggers mutation', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({
        isEditing: true,
        weight: 0,
        mutationHandler: mutationSpy,
        canUpdate: true,
      });
      await nextTick();

      findClearButton().vm.$emit('click');

      expect(mutationSpy).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          weightWidget: {
            weight: null,
          },
        },
      });
    });

    it('calls a mutation to update the weight when the input value is different', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({
        isEditing: true,
        weight: 0,
        mutationHandler: mutationSpy,
        canUpdate: true,
      });
      await nextTick();

      findInput().vm.$emit('input', '1');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSpy).toHaveBeenCalledWith({
        input: {
          id: workItemId,
          weightWidget: {
            weight: 1,
          },
        },
      });
    });

    it('does not call a mutation to update the weight when the input value is the same', async () => {
      const mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
      createComponent({
        isEditing: true,
        weight: 0,
        mutationHandler: mutationSpy,
        canUpdate: true,
      });
      await nextTick();

      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSpy).not.toHaveBeenCalled();
    });

    it('resets the weight value when pressing Escape key', async () => {
      createComponent({ canUpdate: true, isEditing: true, weight: 11 });
      await nextTick();

      findInput().vm.$emit('input', '22');
      await nextTick();

      expect(findInput().props('value')).toBe('22');

      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ESC_KEY }));
      await nextTick();

      expect(wrapper.text()).toContain('11');
      expect(wrapper.text()).not.toContain('22');
    });

    it('emits an error when there is a GraphQL error', async () => {
      const response = {
        data: {
          workItemUpdate: {
            errors: ['Error!'],
            workItem: {},
          },
        },
      };
      createComponent({
        isEditing: true,
        mutationHandler: jest.fn().mockResolvedValue(response),
        canUpdate: true,
      });
      await nextTick();

      findInput().vm.$emit('input', '1');
      findApplyButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('emits an error when there is a network error', async () => {
      createComponent({
        isEditing: true,
        mutationHandler: jest.fn().mockRejectedValue(new Error()),
        canUpdate: true,
      });
      await nextTick();

      findInput().vm.$emit('input', '1');
      findApplyButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the task. Please try again.'],
      ]);
    });

    it('tracks updating the weight', async () => {
      const trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      createComponent({ isEditing: true, canUpdate: true });
      await nextTick();

      findInput().vm.$emit('input', '1');
      findApplyButton().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(TRACKING_CATEGORY_SHOW, 'updated_weight', {
        category: TRACKING_CATEGORY_SHOW,
        label: 'item_weight',
        property: 'type_Task',
      });
    });
  });
});
