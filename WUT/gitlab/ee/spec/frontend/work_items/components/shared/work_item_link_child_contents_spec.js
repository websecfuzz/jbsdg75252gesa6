import { mountExtended } from 'helpers/vue_test_utils_helper';
import WorkItemStateBadge from '~/work_items/components/work_item_state_badge.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import WorkItemLinkChildContents from 'ee/work_items/components/shared/work_item_link_child_contents.vue';

import { workItemTaskEE } from '../../mock_data';

jest.mock('~/alert');

describe('WorkItemLinkChildContentsEE', () => {
  let wrapper;
  const findStatusBadgeComponent = () => wrapper.findComponent(WorkItemStatusBadge);
  const findStateBadgeComponent = () => wrapper.findComponent(WorkItemStateBadge);

  const createComponent = ({
    canUpdate = true,
    childItem = workItemTaskEE,
    showLabels = true,
    workItemFullPath = 'test-project-path',
    isGroup = false,
    workItemStatusFeatureFlag = true,
  } = {}) => {
    wrapper = mountExtended(WorkItemLinkChildContents, {
      propsData: {
        canUpdate,
        childItem,
        showLabels,
        workItemFullPath,
      },
      provide: {
        isGroup,
        hasIterationsFeature: true,
        glFeatures: {
          workItemStatusFeatureFlag,
        },
      },
    });
  };

  describe('work item state badge', () => {
    it('does not render the state badge when the child item is `OPEN` and work item status exists', () => {
      createComponent({
        childItem: {
          ...workItemTaskEE,
          state: 'OPEN',
        },
      });

      expect(findStateBadgeComponent().exists()).toBe(false);
      expect(findStatusBadgeComponent().exists()).toBe(true);
    });

    it('renders the state badge when child item is `CLOSED` and work item status exists', () => {
      createComponent({
        childItem: {
          ...workItemTaskEE,
          state: 'CLOSED',
          closedAt: '2022-08-08T12:41:54Z',
        },
      });

      expect(findStateBadgeComponent().exists()).toBe(true);
      expect(findStatusBadgeComponent().exists()).toBe(true);
    });
  });

  describe('work item status badge', () => {
    it('shows the status badge if the widget exists', () => {
      createComponent();

      expect(findStatusBadgeComponent().exists()).toBe(true);
    });

    it('does not show the badge if the widget does not exist', () => {
      createComponent({
        childItem: {
          ...workItemTaskEE,
          widgets: [],
        },
      });

      expect(findStatusBadgeComponent().exists()).toBe(false);
    });

    it('does not show the badge if the widget exists and the feature flag is disabled', () => {
      createComponent({ workItemStatusFeatureFlag: false });

      expect(findStatusBadgeComponent().exists()).toBe(false);
    });
  });
});
