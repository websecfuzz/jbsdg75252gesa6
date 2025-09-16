import { GlButton, GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { getBaseURL } from '~/lib/utils/url_utility';
import FrameworksNeedsAttention from 'ee/compliance_dashboard/components/dashboard/frameworks_needs_attention.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';

jest.mock('~/lib/utils/url_utility');
describe('FrameworksNeedsAttention', () => {
  let wrapper;

  const mockFrameworks = [
    {
      id: 'gid://gitlab/ComplianceFramework/1',
      framework: {
        id: 'gid://gitlab/ComplianceFramework/1',
        name: 'SOX Framework',
        color: '#ff0000',
        scanExecutionPolicies: {
          nodes: [{ name: 'Scan Policy 1', __typename: 'ScanExecutionPolicy' }],
          pageInfo: { hasNextPage: false },
        },
        vulnerabilityManagementPolicies: {
          nodes: [{ name: 'VM Policy 1', __typename: 'VulnerabilityManagementPolicy' }],
          pageInfo: { hasNextPage: false },
        },
        scanResultPolicies: {
          nodes: [],
          pageInfo: { hasNextPage: false },
        },
        pipelineExecutionPolicies: {
          nodes: [],
          pageInfo: { hasNextPage: false },
        },
      },
      projectsCount: 5,
      requirementsCount: 10,
      requirementsWithoutControls: [
        { id: 'req1', name: 'Requirement 1' },
        { id: 'req2', name: 'Requirement 2' },
      ],
    },
    {
      id: 'gid://gitlab/ComplianceFramework/2',
      framework: {
        id: 'gid://gitlab/ComplianceFramework/2',
        name: 'PCI Framework',
        color: '#00ff00',
        scanExecutionPolicies: {
          nodes: [],
          pageInfo: { hasNextPage: false },
        },
        vulnerabilityManagementPolicies: {
          nodes: [],
          pageInfo: { hasNextPage: false },
        },
        scanResultPolicies: {
          nodes: [],
          pageInfo: { hasNextPage: false },
        },
        pipelineExecutionPolicies: {
          nodes: [],
          pageInfo: { hasNextPage: false },
        },
      },
      projectsCount: 0,
      requirementsCount: 0,
      requirementsWithoutControls: [],
    },
  ];

  const defaultProps = {
    frameworks: mockFrameworks,
  };

  const defaultProvide = {
    groupSecurityPoliciesPath: '/groups/test-group/-/security/policies',
  };

  const findHeaders = () => wrapper.findAll('thead th');
  const findTableRow = (index) => wrapper.findAll('tbody tr').at(index);

  const createComponent = (props = {}, provide = {}, glAbilities = {}) => {
    wrapper = mount(FrameworksNeedsAttention, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
        glAbilities: {
          adminComplianceFramework: true,
          ...glAbilities,
        },
      },
      mocks: {
        $router: {
          push: jest.fn(),
        },
      },
      stubs: {
        FrameworkBadge,
      },
    });
  };

  beforeEach(() => {
    getBaseURL.mockReturnValue('https://gitlab.example.com');
  });

  describe('permissions', () => {
    it('includes actions column when user can admin compliance framework', () => {
      createComponent();
      const headers = findHeaders();
      expect(headers.at(5).text()).toBe('Actions');
    });

    it('excludes actions column when user cannot admin compliance framework', () => {
      createComponent({}, {}, { adminComplianceFramework: false });
      const headers = findHeaders();
      expect(headers).toHaveLength(5);
      expect(headers.wrappers.every((header) => header.text() !== 'Actions')).toBe(true);
    });
  });

  describe('cells rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders FrameworkBadge in framework column', () => {
      const frameworkCell = findTableRow(0).findAll('td').at(0);
      const badge = frameworkCell.findComponent(FrameworkBadge);

      expect(badge.exists()).toBe(true);
      expect(badge.props('framework')).toEqual(mockFrameworks[0].framework);
      expect(badge.props('popoverMode')).toBe('hidden');
    });
  });

  describe('projects count cell rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders project count with danger styling when count is 0', () => {
      const projectsCell = findTableRow(1).findAll('td').at(1);
      const dangerSpan = projectsCell.find('span.gl-text-danger');

      expect(dangerSpan.exists()).toBe(true);
      expect(dangerSpan.classes()).toContain('gl-font-bold');
      expect(dangerSpan.text()).toBe('0');
    });

    it('renders project count normally when count is greater than 0', () => {
      const projectsCell = findTableRow(0).findAll('td').at(1);

      expect(projectsCell.find('span.gl-text-danger').exists()).toBe(false);
      expect(projectsCell.text()).toBe('5');
    });
  });

  describe('requirements count cell rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders requirements count with danger styling when count is 0', () => {
      const requirementsCell = findTableRow(1).findAll('td').at(2);
      const dangerSpan = requirementsCell.find('span.gl-text-danger');

      expect(dangerSpan.exists()).toBe(true);
      expect(dangerSpan.classes()).toContain('gl-font-bold');
      expect(dangerSpan.text()).toBe('0');
    });

    it('renders requirements count normally when count is greater than 0', () => {
      const requirementsCell = findTableRow(0).findAll('td').at(2);

      expect(requirementsCell.find('span.gl-text-danger').exists()).toBe(false);
      expect(requirementsCell.text()).toBe('10');
    });
  });

  describe('requirements without controls cell rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders dash when no requirements without controls', () => {
      const requirementsCell = findTableRow(1).findAll('td').at(3);

      expect(requirementsCell.text()).toBe('-');
    });

    it('renders list of requirements when present', () => {
      const requirementsCell = findTableRow(0).findAll('td').at(3);
      const list = requirementsCell.find('ul');

      expect(list.exists()).toBe(true);
      expect(list.classes()).toContain('gl-pl-3');
      expect(list.classes()).toContain('gl-text-danger');

      const listItems = list.findAll('li');
      expect(listItems).toHaveLength(2);
      expect(listItems.at(0).text()).toBe('Requirement 1');
      expect(listItems.at(1).text()).toBe('Requirement 2');
    });
  });

  describe('policies cell rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders dash when no policies', () => {
      const policiesCell = findTableRow(1).findAll('td').at(4);

      expect(policiesCell.text()).toBe('-');
    });

    it('renders list of policies when present', () => {
      const policiesCell = findTableRow(0).findAll('td').at(4);
      const list = policiesCell.find('ul');

      expect(list.exists()).toBe(true);
      expect(list.classes()).toContain('gl-pl-3');

      const listItems = list.findAll('li');
      expect(listItems).toHaveLength(2);

      const links = policiesCell.findAllComponents(GlLink);
      expect(links).toHaveLength(2);
      expect(links.at(0).text()).toBe('Scan Policy 1');
      expect(links.at(1).text()).toBe('VM Policy 1');
    });
  });

  describe('actions cell rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders edit button when user can admin compliance framework', () => {
      const actionsCell = findTableRow(0).findAll('td').at(5);
      const button = actionsCell.findComponent(GlButton);
      expect(button.text()).toBe('Edit framework');
    });

    it('does not render actions cell when user cannot admin compliance framework', () => {
      createComponent({}, {}, { adminComplianceFramework: false });

      const row = findTableRow(0);
      const cells = row.findAll('td');

      expect(cells).toHaveLength(5);
      expect(cells.wrappers.every((cell) => !cell.findComponent(GlButton).exists())).toBe(true);
    });
  });

  describe('policies rendering behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders policies when policies exist', () => {
      const policiesCell = findTableRow(0).findAll('td').at(4);
      const links = policiesCell.findAllComponents(GlLink);

      expect(links).toHaveLength(2);
      expect(links.at(0).text()).toBe('Scan Policy 1');
      expect(links.at(1).text()).toBe('VM Policy 1');
    });

    it('renders dash when no policies exist', () => {
      const policiesCell = findTableRow(1).findAll('td').at(4);

      expect(policiesCell.text()).toBe('-');
      expect(policiesCell.findAllComponents(GlLink)).toHaveLength(0);
    });
  });
});
