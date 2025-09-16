import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge, GlLoadingIcon } from '@gitlab/ui';
import StatusesList from 'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_list.vue';
import DrawerAccordion from 'ee/compliance_dashboard/components/shared/drawer_accordion.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import complianceRequirementsControlsQuery from 'ee/compliance_dashboard/components/standards_adherence_report/graphql/queries/compliance_requirements_controls.query.graphql';

Vue.use(VueApollo);

jest.mock(
  'ee/compliance_dashboard/components/standards_adherence_report/components/details_drawer/statuses_info',
  () => ({
    statusesInfo: {
      'test-control': {
        description: 'Test control description',
        fixes: [
          {
            title: 'Fix 1',
            description: 'Fix 1 description',
            linkTitle: 'Fix 1 link',
            link: 'https://example.com/fix1',
            ultimate: true,
          },
        ],
      },
    },
  }),
);

describe('StatusesList', () => {
  let wrapper;
  let mockRequirementsControlsQuery;

  const controlStatusesMock = [
    {
      status: 'FAIL',
      complianceRequirementsControl: {
        name: 'control-1',
        controlType: 'internal',
      },
    },
    {
      status: 'PENDING',
      complianceRequirementsControl: {
        name: 'control-2',
        controlType: 'internal',
      },
    },
    {
      status: 'PASS',
      complianceRequirementsControl: {
        name: 'control-3',
        controlType: 'internal',
      },
    },
    {
      status: 'FAIL',
      complianceRequirementsControl: {
        name: 'external-control',
        controlType: 'external',
        externalUrl: 'https://example.com/external',
        externalControlName: 'External control',
      },
    },
  ];

  const mockControlExpressions = [
    { id: 'control-1', name: 'Control One' },
    { id: 'control-2', name: 'Control Two' },
    { id: 'control-3', name: 'Control Three' },
  ];

  const createMockRequirementsControlsResponse = () => ({
    data: {
      complianceRequirementControls: {
        controlExpressions: mockControlExpressions,
      },
    },
  });

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findDrawerAccordion = () => wrapper.findComponent(DrawerAccordion);
  const findAllFailedStatuses = () => wrapper.findAll('.gl-text-status-danger');
  const findAllPendingStatuses = () => wrapper.findAll('.gl-text-status-neutral');
  const findAllPassedStatuses = () => wrapper.findAll('.gl-text-status-success');
  const findFixSection = () => wrapper.findAll('h4').filter((w) => w.text() === 'How to fix');
  const findBadges = () => wrapper.findAllComponents(GlBadge);
  const findTitles = () => wrapper.findAll('h4');

  function createComponent(props = {}) {
    mockRequirementsControlsQuery = jest
      .fn()
      .mockResolvedValue(createMockRequirementsControlsResponse());

    const apolloProvider = createMockApollo([
      [complianceRequirementsControlsQuery, mockRequirementsControlsQuery],
    ]);

    wrapper = mount(StatusesList, {
      propsData: {
        controlStatuses: controlStatusesMock,
        ...props,
      },
      apolloProvider,
    });

    return wrapper;
  }

  describe('loading state', () => {
    it('shows loading icon when data is being fetched', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findDrawerAccordion().exists()).toBe(false);
    });
  });

  describe('after data is loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
      await nextTick();
    });

    it('renders drawer accordion with control statuses', () => {
      expect(findDrawerAccordion().exists()).toBe(true);
      expect(findDrawerAccordion().props('items')).toEqual(
        expect.arrayContaining(controlStatusesMock),
      );
    });

    it('sorts control statuses by status priority (FAIL, PENDING, PASS)', () => {
      const sortedControlStatuses = [
        controlStatusesMock[0], // FAIL
        controlStatusesMock[3], // FAIL (external)
        controlStatusesMock[1], // PENDING
        controlStatusesMock[2], // PASS
      ];

      expect(findDrawerAccordion().props('items')).toEqual(sortedControlStatuses);
    });

    it('displays control name using mapping from API for internal controls', () => {
      expect(findTitles().at(0).text()).toBe('Control One');
    });

    it('displays "External control" for external control types', () => {
      expect(findTitles().at(1).text()).toContain('External control');
      expect(findTitles().at(1).text()).toContain('External');
    });
    it('displays appropriate status indicators for different statuses', () => {
      expect(findAllFailedStatuses()).toHaveLength(2); // 2 failed controls
      expect(findAllPendingStatuses()).toHaveLength(1); // 1 pending control
      expect(findAllPassedStatuses()).toHaveLength(1); // 1 passed control
    });
  });

  describe('fix information', () => {
    beforeEach(async () => {
      // Create a control with a fix available
      const controlWithFix = {
        status: 'FAIL',
        complianceRequirementsControl: {
          name: 'test-control',
          controlType: 'internal',
        },
      };

      createComponent({
        controlStatuses: [controlWithFix],
      });

      await waitForPromises();
      await nextTick();
    });

    it('displays fix section for controls with fixes', () => {
      expect(findFixSection()).toHaveLength(1);
    });

    it('renders Ultimate badge for fixes with ultimate flag', () => {
      const badges = findBadges();
      expect(badges).toHaveLength(1);
      expect(badges.at(0).text()).toBe('Ultimate');
    });
  });
});
