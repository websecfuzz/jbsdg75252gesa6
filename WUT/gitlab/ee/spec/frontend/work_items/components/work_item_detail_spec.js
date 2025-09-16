import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemDetail from '~/work_items/components/work_item_detail.vue';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import workItemUpdatedSubscription from '~/work_items/graphql/work_item_updated.subscription.graphql';
import workspacePermissionsQuery from '~/work_items/graphql/workspace_permissions.query.graphql';
import getAllowedWorkItemChildTypes from '~/work_items/graphql/work_item_allowed_children.query.graphql';

import {
  workItemByIidResponseFactory,
  mockProjectPermissionsQueryResponse,
  allowedChildrenTypesResponse,
} from 'ee_else_ce_jest/work_items/mock_data';

jest.mock('~/lib/utils/common_utils');

describe('EE WorkItemDetail component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const workItemByIidQueryResponse = workItemByIidResponseFactory({
    canUpdate: true,
    canDelete: true,
  });
  const successHandler = jest.fn().mockResolvedValue(workItemByIidQueryResponse);
  const workItemUpdatedSubscriptionHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemUpdated: null } });
  const workspacePermissionsAllowedHandler = jest
    .fn()
    .mockResolvedValue(mockProjectPermissionsQueryResponse());
  const allowedChildrenTypesHandler = jest.fn().mockResolvedValue(allowedChildrenTypesResponse);

  const createComponent = ({ workItemIid = '1', handler = successHandler } = {}) => {
    wrapper = shallowMountExtended(WorkItemDetail, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, handler],
        [workItemUpdatedSubscription, workItemUpdatedSubscriptionHandler],
        [getAllowedWorkItemChildTypes, allowedChildrenTypesHandler],
        [workspacePermissionsQuery, workspacePermissionsAllowedHandler],
      ]),
      isLoggedIn: isLoggedIn(),
      propsData: {
        workItemIid,
      },
      provide: {
        glFeatures: {
          workItemsAlpha: true,
        },
        hasSubepicsFeature: true,
        hasLinkedItemsEpicsFeature: true,
        fullPath: 'group/project',
        groupPath: 'group',
        reportAbusePath: '/report/abuse/path',
      },
      mocks: {
        $router: true,
      },
      stubs: {
        WorkItemVulnerabilities: true,
      },
    });
  };

  beforeEach(() => {
    isLoggedIn.mockReturnValue(true);
  });

  const findVulnerabilitiesWidget = () =>
    wrapper.findComponentByTestId('work-item-vulnerabilities');

  describe('vulnerabilities widget', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('shows vulnerabilities widget', () => {
      expect(findVulnerabilitiesWidget().exists()).toBe(true);
    });
  });
});
