import Vue from 'vue';
import { GlIcon } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkItemRolledUpData from '~/work_items/components/work_item_links/work_item_rolled_up_data.vue';
import WorkItemRolledUpHealthStatus from 'ee/work_items/components/work_item_links/work_item_rolled_up_health_status.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import { workItemByIidResponseFactory, mockRolledUpHealthStatus } from '../../mock_data';

Vue.use(VueApollo);

describe('WorkItemRolledUpData', () => {
  let wrapper;

  const findRolledUpWeight = () => wrapper.findByTestId('work-item-rollup-weight');
  const findRolledUpWeightValue = () => wrapper.findByTestId('work-item-weight-value');
  const findRolledUpProgress = () => wrapper.findByTestId('work-item-rollup-progress');
  const findRolledUpProgressValue = () => wrapper.findByTestId('work-item-progress-value');
  const findWorkItemRolledUpHealthStatus = () =>
    wrapper.findComponent(WorkItemRolledUpHealthStatus);

  const workItemQueryResponse = workItemByIidResponseFactory({
    canUpdate: true,
    canDelete: true,
  });
  const workItemSuccessQueryHandler = jest.fn().mockResolvedValue(workItemQueryResponse);

  const createComponent = ({
    workItemType = 'Objective',
    workItemIid = '2',
    workItemQueryHandler = workItemSuccessQueryHandler,
    rolledUpHealthStatus = mockRolledUpHealthStatus,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemRolledUpData, {
      propsData: {
        rolledUpCountsByType: [],
        fullPath: 'test/project',
        workItemType,
        workItemIid,
        rolledUpHealthStatus,
      },
      apolloProvider: createMockApollo([[workItemByIidQuery, workItemQueryHandler]]),
    });
  };

  describe('rolled up weight', () => {
    it.each`
      isRollUp | rolledUpWeight | rollUpWeightVisible | expected
      ${false} | ${0}           | ${false}            | ${'rollup weight is not displayed'}
      ${false} | ${10}          | ${false}            | ${'rollup weight is not displayed'}
      ${true}  | ${0}           | ${true}             | ${'rollup weight is displayed'}
      ${true}  | ${null}        | ${false}            | ${'rollup weight is not displayed'}
      ${true}  | ${10}          | ${true}             | ${'rollup weight is displayed'}
    `(
      'When the roll up weight is $isRollUp and rolledUpWeight is $rolledUpWeight, $expected',
      async ({ isRollUp, rollUpWeightVisible, rolledUpWeight }) => {
        const workItemResponse = workItemByIidResponseFactory({
          canUpdate: true,
          rolledUpWeight,
          editableWeightWidget: !isRollUp,
        });
        createComponent({
          workItemQueryHandler: jest.fn().mockResolvedValue(workItemResponse),
        });

        await waitForPromises();

        expect(findRolledUpWeight().exists()).toBe(rollUpWeightVisible);
      },
    );

    it('should show the correct value when rolledUpWeight is visible', async () => {
      const workItemResponse = workItemByIidResponseFactory({
        canUpdate: true,
        rolledUpWeight: 10,
        editableWeightWidget: false,
      });
      createComponent({ workItemQueryHandler: jest.fn().mockResolvedValue(workItemResponse) });

      await waitForPromises();

      expect(findRolledUpWeight().exists()).toBe(true);
      expect(findRolledUpWeight().findComponent(GlIcon).props('name')).toBe('weight');
      expect(findRolledUpWeightValue().text()).toBe('10');
    });
  });

  describe('rolled up progress', () => {
    it('should not show the rolled up progress when rolled up weight is null', async () => {
      const workItemResponse = workItemByIidResponseFactory({
        canUpdate: true,
        rolledUpWeight: null,
        editableWeightWidget: false,
      });
      createComponent({ workItemQueryHandler: jest.fn().mockResolvedValue(workItemResponse) });

      await waitForPromises();

      expect(findRolledUpProgress().exists()).toBe(false);
      expect(findRolledUpProgressValue().exists()).toBe(false);
    });

    it('should show the correct value when rolledUpWeight and rolledUpCompletedWeight exist', async () => {
      const workItemResponse = workItemByIidResponseFactory({
        canUpdate: true,
        rolledUpWeight: 12,
        rolledUpCompletedWeight: 5,
        editableWeightWidget: false,
      });
      createComponent({ workItemQueryHandler: jest.fn().mockResolvedValue(workItemResponse) });

      await waitForPromises();

      expect(findRolledUpProgress().exists()).toBe(true);
      expect(findRolledUpProgress().findComponent(GlIcon).props('name')).toBe('progress');
      expect(findRolledUpProgressValue().text()).toBe('42%');
    });
  });

  it('rolled up health status', async () => {
    createComponent();

    await waitForPromises();

    expect(findWorkItemRolledUpHealthStatus().exists()).toBe(true);
  });

  it('when the query is not successful , and error is emitted', async () => {
    const errorHandler = jest.fn().mockRejectedValue('Oops');
    createComponent({ workItemQueryHandler: errorHandler });
    await waitForPromises();

    expect(wrapper.emitted('error')).toHaveLength(1);
  });
});
