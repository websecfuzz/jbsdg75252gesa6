import { GlIcon, GlLink, GlTruncate } from '@gitlab/ui';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { queryToObject, getLocationHash, setLocationHash } from '~/lib/utils/url_utility';
import { subgroupsAndProjects } from '../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  queryToObject: jest.fn().mockReturnValue({}),
  getLocationHash: jest.fn().mockReturnValue(''),
  setLocationHash: jest.fn().mockReturnValue(''),
}));

describe('NameCell', () => {
  let wrapper;

  const $toast = {
    show: jest.fn(),
  };
  const mockProject = subgroupsAndProjects.data.group.projects.nodes[0];
  const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];

  const createComponent = (prop = {}) => {
    wrapper = shallowMountExtended(NameCell, {
      propsData: { item: mockProject, showSearchParam: false, ...prop },
      mocks: {
        $toast,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLink = () => wrapper.findComponent(GlLink);
  const findAvatar = () => wrapper.findComponent(ProjectAvatar);
  const findTruncate = () => wrapper.findComponent(GlTruncate);
  const findByTestId = (id) => wrapper.findByTestId(id);

  describe('project view', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders icon and text correctly', () => {
      expect(findIcon().props('name')).toBe('project');
      expect(findByTestId('name-cell-item-name').text()).toBe(mockProject.name);
    });

    it('does not render full path for projects only', () => {
      expect(findByTestId('name-cell-item-path').exists()).toBe(false);
      expect(findTruncate().exists()).toBe(false);
    });

    it('renders full path while searching for projects only', () => {
      queryToObject.mockReturnValue({ search: 'url-search' });
      createComponent({ showSearchParam: true });
      expect(findTruncate().props('text')).toBe('flightjs');
    });

    it('redirect to sub group while clicking the sub path', async () => {
      createComponent({ showSearchParam: true });
      getLocationHash.mockReturnValue('url-search');
      await findByTestId('name-cell-item-path').trigger('click');
      setLocationHash.mockReturnValue('url-search');
      expect(getLocationHash()).toBe('url-search');
      expect($toast.show).not.toHaveBeenCalled();
    });

    it('does not redirect to sub group while clicking the current path', async () => {
      createComponent({ showSearchParam: true });
      getLocationHash.mockReturnValue('flightjs');
      await findByTestId('name-cell-item-path').trigger('click');
      expect(getLocationHash()).toBe('flightjs');
      expect($toast.show).toHaveBeenCalledWith("You're already viewing this subgroup");
    });

    it('does not render a link', () => {
      expect(findLink().exists()).toBe(false);
    });

    it('renders the correct avatar props', () => {
      expect(findAvatar().props()).toMatchObject({
        projectId: mockProject.id,
        projectName: mockProject.name,
        projectAvatarUrl: mockProject.avatarUrl,
      });
    });
  });

  describe('group view', () => {
    beforeEach(() => {
      createComponent({ item: mockGroup });
    });

    it('renders icon and text correctly', () => {
      expect(findIcon().props('name')).toBe('subgroup');
      expect(wrapper.text()).toContain(mockGroup.name);
      expect(wrapper.text()).toContain(
        `${mockGroup.projectsCount} project, ${mockGroup.descendantGroupsCount} subgroups`,
      );
    });

    it('does not render full path for groups', () => {
      expect(findByTestId('name-cell-item-path').exists()).toBe(false);
    });

    it('renders the correct link', () => {
      expect(findLink().exists()).toBe(true);
      expect(findLink().attributes('href')).toBe(`#${mockGroup.fullPath}`);
    });

    it('renders the correct avatar props', () => {
      expect(findAvatar().props()).toMatchObject({
        projectId: mockGroup.id,
        projectName: mockGroup.name,
        projectAvatarUrl: mockGroup.avatarUrl,
      });
    });
  });
});
