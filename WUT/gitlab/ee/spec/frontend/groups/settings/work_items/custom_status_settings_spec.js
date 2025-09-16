import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlButton, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import NamespaceLifecycles from 'ee/groups/settings/work_items/custom_status_settings.vue';
import namespaceStatusesQuery from 'ee/groups/settings/work_items/namespace_lifecycles.query.graphql';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

const mockLifecycles = [
  {
    id: 'gid://gitlab/WorkItems::Lifecycle/1',
    name: 'Development',
    defaultOpenStatus: { id: '1', name: 'Open' },
    defaultClosedStatus: { id: '2', name: 'Closed' },
    defaultDuplicateStatus: { id: '3', name: 'Duplicate' },
    workItemTypes: [
      { id: 'gid://gitlab/WorkItems::Type/1', name: 'Issue', iconName: 'issue-type-issue' },
      { id: 'gid://gitlab/WorkItems::Type/2', name: 'Task', iconName: 'issue-type-task' },
    ],
    statuses: [
      { id: '1', name: 'Open', iconName: 'issue-open', color: 'green', description: '' },
      { id: '2', name: 'In Progress', iconName: 'progress', color: 'blue', description: '' },
      { id: '3', name: 'Closed', iconName: 'issue-closed', color: 'gray', description: '' },
    ],
  },
  {
    id: 'gid://gitlab/WorkItems::Lifecycle/2',
    name: 'Operations',
    defaultOpenStatus: { id: '4', name: 'New' },
    defaultClosedStatus: { id: '5', name: 'Resolved' },
    defaultDuplicateStatus: { id: '6', name: 'Duplicate' },
    workItemTypes: [
      { id: 'gid://gitlab/WorkItems::Type/3', name: 'Incident', iconName: 'issue-type-incident' },
    ],
    statuses: [
      { id: '4', name: 'New', iconName: 'issue-new', color: 'red', description: '' },
      { id: '5', name: 'Resolved', iconName: 'check', color: 'green', description: '' },
    ],
  },
];

describe('CustomStatusSettings', () => {
  let wrapper;
  let apolloProvider;

  const createQueryResponse = (lifecycles = mockLifecycles) => ({
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        lifecycles: {
          nodes: lifecycles,
        },
      },
    },
  });

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLifecycleContainers = () => wrapper.findAll('[data-testid="lifecycle-container"]');
  const findStatusBadges = () => wrapper.findAllComponents(WorkItemStatusBadge);
  const findEditButtons = () => wrapper.findAllComponents(GlButton);

  const createComponent = ({
    props = {},
    queryHandler = jest.fn().mockResolvedValue(createQueryResponse()),
  } = {}) => {
    apolloProvider = createMockApollo([[namespaceStatusesQuery, queryHandler]]);

    wrapper = shallowMountExtended(NamespaceLifecycles, {
      propsData: {
        fullPath: 'gitlab-org',
        ...props,
      },
      apolloProvider,
    });
  };

  describe('query success', () => {
    beforeEach(() => {
      createComponent();
      return waitForPromises();
    });

    it('renders correct number of lifecycle containers', () => {
      expect(findLifecycleContainers()).toHaveLength(2);
    });

    it('renders work item types with icons and names', () => {
      const firstLifecycle = findLifecycleContainers().at(0);
      const icons = firstLifecycle.findAllComponents(GlIcon);

      expect(icons.at(0).props('name')).toBe('issue-type-issue');
      expect(firstLifecycle.text()).toContain('Issue');
      expect(icons.at(1).props('name')).toBe('issue-type-task');
      expect(firstLifecycle.text()).toContain('Task');
    });

    it('renders status badges with correct props', () => {
      const statusBadges = findStatusBadges();

      expect(statusBadges).toHaveLength(5); // 3 from first lifecycle + 2 from second

      expect(statusBadges.at(0).props()).toMatchObject({
        item: {
          name: 'Open',
          iconName: 'issue-open',
          color: 'green',
        },
      });

      expect(statusBadges.at(1).props()).toMatchObject({
        item: {
          name: 'In Progress',
          iconName: 'progress',
          color: 'blue',
        },
      });
    });

    it('renders edit button for each lifecycle', () => {
      const editButtons = findEditButtons();

      expect(editButtons).toHaveLength(2);
      expect(editButtons.at(0).text()).toBe('Edit statuses');
      expect(editButtons.at(0).props('size')).toBe('small');
    });
  });

  describe('when query fails', () => {
    const error = new Error('GraphQL error');

    beforeEach(() => {
      createComponent({
        queryHandler: jest.fn().mockRejectedValue(error),
      });
      return waitForPromises();
    });

    it('displays error alert', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().props('dismissible')).toBe(true);
      expect(findAlert().text()).toContain('Failed to load statuses.');
      expect(findAlert().find('details').text()).toContain(error.message);
    });

    it('calls Sentry.captureException', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });

    it('hides alert when dismissed', async () => {
      expect(findAlert().exists()).toBe(true);

      findAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });
});
