import { GlIcon, GlTooltip } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import WorkItemRolledUpHealthStatus from 'ee/work_items/components/work_item_links/work_item_rolled_up_health_status.vue';
import WorkItemLinkChildMetadata from 'ee/work_items/components/shared/work_item_link_child_metadata.vue';
import WorkItemIterationAttribute from 'ee/work_items/components/shared/work_item_iteration_attribute.vue';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';
import { workItemObjectiveMetadataWidgetsEE } from '../../mock_data';

describe('WorkItemLinkChildMetadataEE', () => {
  const { PROGRESS, HEALTH_STATUS, WEIGHT, ITERATION } = workItemObjectiveMetadataWidgetsEE;

  let wrapper;

  const createComponent = ({
    metadataWidgets = workItemObjectiveMetadataWidgetsEE,
    showWeight = true,
    workItemType = 'Task',
    isChildItemOpen = true,
    hasIterationsFeature = false,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemLinkChildMetadata, {
      provide: {
        hasIterationsFeature,
      },
      propsData: {
        iid: '1',
        reference: 'test-project-path#1',
        metadataWidgets,
        showWeight,
        workItemType,
        isChildItemOpen,
      },
      stubs: {
        WorkItemAttribute,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findWeight = () => wrapper.findByTestId('item-weight');
  const findWeightTooltip = () => wrapper.findByTestId('weight-tooltip');
  const findRolledUpHealthStatus = () => wrapper.findComponent(WorkItemRolledUpHealthStatus);
  const findWorkItemAttribute = () => wrapper.findAllComponents(WorkItemAttribute);

  describe('progress', () => {
    it('renders item progress icon and percentage completion', () => {
      const progressEl = wrapper.findByTestId('item-progress');

      expect(progressEl.exists()).toBe(true);
      expect(progressEl.findComponent(GlIcon).props('name')).toBe('progress');
      expect(wrapper.findByTestId('progressValue').text().trim()).toBe(`${PROGRESS.progress}%`);
    });

    it('renders gl-tooltip', () => {
      const progressEl = wrapper.findByTestId('item-progress');

      expect(progressEl.findComponent(GlTooltip).isVisible()).toBe(true);
    });

    it('renders progressTitle in bold', () => {
      expect(wrapper.findByTestId('progressTitle').text().trim()).toBe('Progress');
    });

    it('renders progressText in bold', () => {
      expect(wrapper.findByTestId('progressText').text().trim()).toBe('Last updated');
    });

    it('renders lastUpdatedInWords', () => {
      expect(wrapper.findByTestId('lastUpdatedInWords').text().trim()).toContain('just now');
    });

    it('renders lastUpdatedTimestamp in muted', () => {
      expect(wrapper.findByTestId('lastUpdatedTimestamp').text().trim()).toContain(
        localeDateFormat.asDateTimeFull.format(newDate(PROGRESS.updatedAt)),
      );
    });
  });

  describe('metadata weight', () => {
    it('renders item weight icon and value', () => {
      expect(findWorkItemAttribute().at(0).exists()).toBe(true);
      expect(findWorkItemAttribute().at(0).props('iconName')).toBe('weight');
      expect(findWorkItemAttribute().at(0).props('title')).toBe(`${WEIGHT.weight}`);
    });

    it('renders rollup weight with icon and value when widget has rollUp weight', () => {
      const rolledUpWeightWidget = {
        type: 'WEIGHT',
        weight: null,
        rolledUpWeight: 5,
        widgetDefinition: {
          editable: false,
          rollUp: true,
          __typename: 'WorkItemWidgetDefinitionWeight',
        },
        __typename: 'WorkItemWidgetWeight',
      };
      createComponent({
        metadataWidgets: {
          WEIGHT: rolledUpWeightWidget,
        },
      });

      expect(findWorkItemAttribute().at(0).exists()).toBe(true);
      expect(findWorkItemAttribute().at(0).props('iconName')).toBe('weight');
      expect(findWorkItemAttribute().at(0).props('title')).toBe(
        `${rolledUpWeightWidget.rolledUpWeight}`,
      );
    });

    it('does not render item weight on `showWeight` is false', () => {
      createComponent({
        showWeight: false,
      });

      expect(findWeight().exists()).toBe(false);
    });

    it('renders tooltip', () => {
      createComponent();

      expect(findWeightTooltip().text()).toBe('Weight');
    });

    it('shows `Issue weight` in the tooltip when the parent is an Epic', () => {
      createComponent({
        workItemType: 'Epic',
      });

      expect(findWeightTooltip().text()).toBe('Issue weight');
    });
  });

  describe('dates', () => {
    it('renders item date icon and value', () => {
      const datesEl = wrapper.findByTestId('item-dates');

      expect(findWorkItemAttribute().at(1).exists()).toBe(true);
      expect(datesEl.findComponent(GlIcon).props('name')).toBe('calendar');
      expect(findWorkItemAttribute().at(1).props('title')).toBe('Jan 1 – Jun 27, 2024');
    });

    it('renders item with no start date', () => {
      createComponent({
        metadataWidgets: {
          START_AND_DUE_DATE: {
            type: 'START_AND_DUE_DATE',
            startDate: null,
            dueDate: '2024-06-27',
            __typename: 'WorkItemWidgetStartAndDueDate',
          },
        },
      });

      expect(findWorkItemAttribute().at(0).props('title')).toBe('No start date – Jun 27, 2024');
    });

    it('renders item with no end date', () => {
      createComponent({
        metadataWidgets: {
          START_AND_DUE_DATE: {
            type: 'START_AND_DUE_DATE',
            startDate: '2024-06-27',
            dueDate: null,
            __typename: 'WorkItemWidgetStartAndDueDate',
          },
        },
      });

      expect(findWorkItemAttribute().at(0).props('title')).toBe('Jun 27, 2024 – No due date');
    });

    describe('when due date in the past', () => {
      let overdueDate = new Date();
      overdueDate = overdueDate.getDate() - 17;

      describe('when work item is open', () => {
        it('renders as overdue', () => {
          createComponent({
            metadataWidgets: {
              START_AND_DUE_DATE: {
                type: 'START_AND_DUE_DATE',
                startDate: null,
                dueDate: overdueDate,
                __typename: 'WorkItemWidgetStartAndDueDate',
              },
            },
          });

          expect(wrapper.findByTestId('item-dates').findComponent(GlIcon).props()).toMatchObject({
            variant: 'danger',
            name: 'calendar-overdue',
          });
        });
      });

      describe('when issue is closed', () => {
        it('does not render as overdue', () => {
          createComponent({
            metadataWidgets: {
              START_AND_DUE_DATE: {
                type: 'START_AND_DUE_DATE',
                startDate: null,
                dueDate: overdueDate,
                __typename: 'WorkItemWidgetStartAndDueDate',
              },
            },
            isChildItemOpen: false,
          });

          expect(wrapper.findByTestId('item-dates').findComponent(GlIcon).props()).toMatchObject({
            variant: 'current',
            name: 'calendar',
          });
        });
      });
    });
  });

  describe('iteration', () => {
    const findIteration = () => wrapper.findComponent(WorkItemIterationAttribute);

    it('renders iteration', () => {
      createComponent({
        hasIterationsFeature: true,
      });

      expect(findIteration().exists()).toBe(true);
    });

    it('does not render iteration when iteration data is not present', () => {
      createComponent({
        metadataWidgets: {
          ...ITERATION,
          iteration: null,
        },
        hasIterationsFeature: false,
      });
      expect(findIteration().exists()).toBe(false);
    });

    it('does not render when iteration feature is disabled', () => {
      createComponent({
        hasIterationsFeature: false,
      });

      expect(findIteration().exists()).toBe(false);
    });
  });

  it('renders rolled up health status when rolled up health status values exist', () => {
    const { rolledUpHealthStatus } = HEALTH_STATUS;

    expect(findRolledUpHealthStatus().exists()).toBe(true);
    expect(findRolledUpHealthStatus().props()).toEqual({
      rolledUpHealthStatus,
      healthStatusVisible: true,
    });
  });

  it('renders health status badge when the health status is open', () => {
    const { healthStatus } = HEALTH_STATUS;

    expect(wrapper.findComponent(IssueHealthStatus).props('healthStatus')).toBe(healthStatus);
  });

  it('does not render health status badge when the work item is closed', () => {
    createComponent({ isChildItemOpen: false });

    expect(wrapper.findComponent(IssueHealthStatus).exists()).toBe(false);
  });
});
