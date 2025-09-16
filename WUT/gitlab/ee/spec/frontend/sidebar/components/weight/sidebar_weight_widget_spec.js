import { GlButton, GlForm, GlFormInput } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import SidebarWeightWidget from 'ee_component/sidebar/components/weight/sidebar_weight_widget.vue';
import issueWeightQuery from 'ee_component/sidebar/queries/issue_weight.query.graphql';
import updateIssueWeightMutation from 'ee_component/sidebar/queries/update_issue_weight.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import { preventDefault, stopPropagation } from 'ee_jest/admin/test_helpers';
import { createAlert } from '~/alert';
import SidebarEditableItem from '~/sidebar/components/sidebar_editable_item.vue';
import issueWeightSubscription from 'ee/graphql_shared/subscriptions/issuable_weight.subscription.graphql';
import {
  issueNoWeightResponse,
  issueWeightResponse,
  setWeightResponse,
  removeWeightResponse,
  issueWeightSubscriptionResponse,
  mockIssueId,
} from '../../mock_data';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('Sidebar Weight Widget', () => {
  let wrapper;
  let fakeApollo;

  const findEditableItem = () => wrapper.findComponent(SidebarEditableItem);
  const findRemoveButton = () => wrapper.findComponent(GlButton);
  const findWeightValue = () => wrapper.findByTestId('sidebar-weight-value');
  const findFormInput = () => wrapper.findComponent(GlFormInput);
  const findForm = () => wrapper.findComponent(GlForm);

  const createFakeEvent = () => ({ preventDefault, stopPropagation });
  const createComponent = ({
    weightQueryHandler = jest.fn().mockResolvedValue(issueNoWeightResponse()),
    weightMutationHandler = jest.fn().mockResolvedValue(setWeightResponse()),
    weightSubscriptionHandler = jest.fn().mockResolvedValue(issueWeightSubscriptionResponse()),
  } = {}) => {
    fakeApollo = createMockApollo([
      [issueWeightQuery, weightQueryHandler],
      [updateIssueWeightMutation, weightMutationHandler],
      [issueWeightSubscription, weightSubscriptionHandler],
    ]);

    wrapper = shallowMountExtended(SidebarWeightWidget, {
      apolloProvider: fakeApollo,
      provide: {
        canUpdate: true,
      },
      propsData: {
        fullPath: 'group/project',
        iid: '1',
        issuableType: 'issue',
      },
      stubs: {
        SidebarEditableItem: stubComponent(SidebarEditableItem, {
          methods: { collapse: jest.fn() },
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  afterEach(() => {
    fakeApollo = null;
  });

  it('passes a `loading` prop as true to editable item when query is loading', () => {
    createComponent();

    expect(findEditableItem().props('loading')).toBe(true);
  });

  describe('when issue has no weight', () => {
    beforeEach(() => {
      createComponent();
      return waitForPromises();
    });

    it('passes a `loading` prop as false to editable item', () => {
      expect(findEditableItem().props('loading')).toBe(false);
    });

    it('toggle is unchecked', () => {
      expect(findWeightValue().text()).toBe('None');
    });

    it('does not display remove option', () => {
      expect(findRemoveButton().exists()).toBe(false);
    });

    it('sets weight', async () => {
      findEditableItem().vm.$emit('open');
      findFormInput().vm.$emit('input', '2');
      findForm().vm.$emit('submit', createFakeEvent());
      await waitForPromises();

      expect(findWeightValue().text()).toBe('2');
      expect(wrapper.emitted('weightUpdated')).toEqual([[{ id: mockIssueId, weight: 2 }]]);
    });
  });

  describe('when issue has weight', () => {
    beforeEach(() => {
      createComponent({
        weightQueryHandler: jest.fn().mockResolvedValue(issueWeightResponse()),
        weightMutationHandler: jest.fn().mockResolvedValue(removeWeightResponse()),
      });
      return waitForPromises();
    });

    it('passes a `loading` prop as false to editable item', () => {
      expect(findEditableItem().props('loading')).toBe(false);
    });

    it('toggle is checked', () => {
      expect(findWeightValue().text()).toBe('0');
    });

    it('displays remove option - removes weight', async () => {
      expect(findRemoveButton().exists()).toBe(true);
      findRemoveButton().vm.$emit('click');
      await waitForPromises();

      expect(findWeightValue().text()).toBe('None');
      expect(wrapper.emitted('weightUpdated')).toEqual([[{ id: mockIssueId, weight: null }]]);
    });
  });

  describe('updates existing weight', () => {
    beforeEach(() => {
      createComponent({
        weightQueryHandler: jest.fn().mockResolvedValue(issueWeightResponse(2)),
        weightMutationHandler: jest.fn().mockResolvedValue(setWeightResponse(3)),
      });
      return waitForPromises();
    });

    it('emits weight difference', async () => {
      findEditableItem().vm.$emit('open');
      findFormInput().vm.$emit('input', '3');
      findForm().vm.$emit('submit', createFakeEvent());
      await waitForPromises();

      expect(findWeightValue().text()).toBe('3');
      expect(wrapper.emitted('weightUpdated')).toEqual([[{ id: mockIssueId, weight: 1 }]]);
    });
  });

  it('displays an alert message when query is rejected', async () => {
    createComponent({
      weightQueryHandler: jest.fn().mockRejectedValue('Houston, we have a problem'),
    });
    await waitForPromises();

    expect(createAlert).toHaveBeenCalled();
  });

  describe('real time issue weight', () => {
    it('should call the subscription', async () => {
      const weightSubscriptionHandler = jest
        .fn()
        .mockResolvedValue(issueWeightSubscriptionResponse());
      createComponent({ weightSubscriptionHandler });
      await waitForPromises();

      expect(weightSubscriptionHandler).toHaveBeenCalled();
    });
  });
});
