import Vue, { nextTick } from 'vue';
import { GlBadge } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemVulnerabilities from 'ee/work_items/components/work_item_vulnerabilities.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import workItemVulnerabilitiesQuery from 'ee/work_items/graphql/work_item_vulnerabilities.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemVulnerabilityItem from 'ee/work_items/components/work_item_vulnerability_item.vue';
import {
  vulnerabilitiesWidgetResponse,
  emptyVulnerabilitiesWidgetResponse,
  paginatedVulnerabilitiesWidgetResponse,
} from '../mock_data';

jest.mock('~/alert');

const items =
  vulnerabilitiesWidgetResponse.data.workspace.workItem.widgets[0].relatedVulnerabilities.nodes;

describe('WorkItemVulnerabilities component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemIid = '1';
  const fullPath = 'gitlab-org/security-reports';
  const successHandler = jest.fn().mockResolvedValue(vulnerabilitiesWidgetResponse);

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findAllVulnerabilityItems = () => wrapper.findAllComponents(WorkItemVulnerabilityItem);

  const createComponent = ({ handler = successHandler } = {}) => {
    wrapper = shallowMountExtended(WorkItemVulnerabilities, {
      apolloProvider: createMockApollo([[workItemVulnerabilitiesQuery, handler]]),
      propsData: {
        workItemIid,
        workItemFullPath: fullPath,
      },
      stubs: {
        CrudComponent,
      },
    });
  };

  beforeEach(async () => {
    createComponent();

    await waitForPromises();
  });

  describe('Default', () => {
    it('fetches vulnerabilities widget', () => {
      expect(successHandler).toHaveBeenCalledWith({
        iid: workItemIid,
        fullPath,
        first: 25,
        after: '',
      });
    });

    it('shows CRUD Component', () => {
      const crudComponent = findCrudComponent();
      expect(crudComponent.props()).toMatchObject({
        title: 'Related vulnerabilities',
        anchorId: 'vulnerabilitiesitems',
      });
    });

    it('shows WorkItemVulnerabilityItem components', () => {
      expect(findAllVulnerabilityItems()).toHaveLength(2);
    });

    it('passes vulnerability to WorkItemVulnerabilityItem', () => {
      const firstItem = items[0];
      expect(findAllVulnerabilityItems().at(0).props('item')).toEqual(firstItem);
    });
  });

  describe('count badge', () => {
    it('shows correct aria-label and count with multiple related vulnerabilities', () => {
      const badge = findBadge();
      expect(badge.attributes('aria-label')).toBe('Issue has 2 related vulnerabilities');
      expect(badge.text()).toBe('2');
    });
  });

  describe('no related vulnerabilities', () => {
    beforeEach(async () => {
      createComponent({ handler: jest.fn().mockResolvedValue(emptyVulnerabilitiesWidgetResponse) });
      await waitForPromises;
    });

    it('does not show CrudComponent', () => {
      expect(findCrudComponent().exists()).toBe(false);
    });
  });

  describe('load more', () => {
    const findWorkItemChildrenLoadMore = () =>
      wrapper.findByTestId('work-item-vulnerabilities-load-more');

    let paginatedHandler;

    beforeEach(async () => {
      paginatedHandler = jest.fn().mockResolvedValue(paginatedVulnerabilitiesWidgetResponse);

      createComponent({
        handler: paginatedHandler,
      });

      await waitForPromises();
    });

    it('shows `Load more` button when hasNextPage is true and node is expanded', () => {
      const loadMore = findWorkItemChildrenLoadMore();
      expect(loadMore.exists()).toBe(true);
      expect(loadMore.props('fetchNextPageInProgress')).toBe(false);
    });

    it('fetches next page when clicking on `Load more`', async () => {
      const loadMore = findWorkItemChildrenLoadMore();
      loadMore.vm.$emit('fetch-next-page');
      await nextTick();

      expect(loadMore.props('fetchNextPageInProgress')).toBe(true);
      await waitForPromises();

      expect(loadMore.props('fetchNextPageInProgress')).toBe(false);
      expect(paginatedHandler).toHaveBeenNthCalledWith(2, {
        iid: workItemIid,
        fullPath,
        after: 'XYZ',
        first: 50,
      });
    });

    it('shows alert message when fetching next page fails', async () => {
      const rejectPaginationHandler = jest
        .fn()
        .mockResolvedValueOnce(paginatedVulnerabilitiesWidgetResponse)
        .mockRejectedValue('Error');
      createComponent({
        handler: rejectPaginationHandler,
      });

      await waitForPromises();
      findWorkItemChildrenLoadMore().vm.$emit('fetch-next-page');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        error: expect.any(Object),
        message: 'Something went wrong while fetching more related vulnerabilities.',
      });
    });
  });
});
