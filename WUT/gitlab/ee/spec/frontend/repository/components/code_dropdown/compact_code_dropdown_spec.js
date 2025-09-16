import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';
import CeCompactCodeDropdown from '~/repository/components/code_dropdown/compact_code_dropdown.vue';
import WorkspacesDropdownGroup from 'ee/workspaces/dropdown_group/components/workspaces_dropdown_group.vue';
import GetProjectDetailsQuery from 'ee/workspaces/common/components/get_project_details_query.vue';
import CompactCodeDropdown from 'ee/repository/components/code_dropdown/compact_code_dropdown.vue';

describe('EE Compact Code Dropdown component', () => {
  let wrapper;
  const sshUrl = 'ssh://foo.bar';
  const httpUrl = 'http://foo.bar';
  const xcodeUrl = 'xcode://foo.bar';
  const currentPath = null;
  const projectPath = 'group/project';
  const projectId = '123';
  const newWorkspacePath = '/workspaces/new';
  const organizationId = '1';
  const directoryDownloadLinks = [
    { text: 'zip', path: `${httpUrl}/archive.zip` },
    { text: 'tar.gz', path: `${httpUrl}/archive.tar.gz` },
  ];

  const defaultPropsData = {
    sshUrl,
    httpUrl,
    xcodeUrl,
    currentPath,
    directoryDownloadLinks,
    projectPath,
    projectId,
  };

  // Helper functions to find components
  const findCeCompactCodeDropdown = () => wrapper.findComponent(CeCompactCodeDropdown);
  const findGetProjectDetailsQuery = () => wrapper.findComponent(GetProjectDetailsQuery);
  const findWorkspacesDropdownGroup = () => wrapper.findComponent(WorkspacesDropdownGroup);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  // Create component with feature flags
  const createComponent = ({ propsData = defaultPropsData, remoteDevelopmentFlag = true } = {}) => {
    wrapper = shallowMount(CompactCodeDropdown, {
      propsData,
      stubs: {
        CeCompactCodeDropdown,
        GetProjectDetailsQuery: true,
        WorkspacesDropdownGroup: true,
      },
      provide: {
        glFeatures: { remoteDevelopment: remoteDevelopmentFlag },
        newWorkspacePath,
        organizationId,
      },
    });
  };

  describe('base dropdown', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the CE compact code dropdown with correct props', () => {
      const dropdown = findCeCompactCodeDropdown();
      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props()).toMatchObject({
        sshUrl,
        httpUrl,
        xcodeUrl,
        currentPath,
        directoryDownloadLinks,
      });
    });
  });

  // Tests for workspaces dropdown group
  describe('workspaces dropdown group', () => {
    it('renders workspaces section when feature flag is enabled', async () => {
      createComponent();
      await findGetProjectDetailsQuery().vm.$emit('result', { clusterAgents: [{ id: 1 }] });
      expect(findWorkspacesDropdownGroup().exists()).toBe(true);
    });

    it('does not render workspaces section when feature flag is disabled', () => {
      createComponent({ remoteDevelopmentFlag: false });
      expect(findGetProjectDetailsQuery().exists()).toBe(false);
      expect(findWorkspacesDropdownGroup().exists()).toBe(false);
    });

    it('shows loading icon before project details are loaded', () => {
      createComponent();
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findWorkspacesDropdownGroup().exists()).toBe(false);
    });

    it('renders workspaces dropdown when project details are loaded', async () => {
      createComponent();

      await findGetProjectDetailsQuery().vm.$emit('result', { clusterAgents: [{ id: 1 }] });

      expect(findWorkspacesDropdownGroup().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);

      const workspacesDropdown = findWorkspacesDropdownGroup();
      expect(workspacesDropdown.props()).toMatchObject({
        projectId: parseInt(projectId, 10),
        projectFullPath: projectPath,
        supportsWorkspaces: true,
        newWorkspacePath,
      });
    });

    it('handles error in project details', async () => {
      createComponent();

      await findGetProjectDetailsQuery().vm.$emit('error');

      expect(findWorkspacesDropdownGroup().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('sets supportsWorkspaces to false when no cluster agents', async () => {
      createComponent();

      await findGetProjectDetailsQuery().vm.$emit('result', { clusterAgents: [] });

      expect(findWorkspacesDropdownGroup().props('supportsWorkspaces')).toBe(false);
    });
  });
});
