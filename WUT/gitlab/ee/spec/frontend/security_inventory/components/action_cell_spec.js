import { shallowMount } from '@vue/test-utils';
import { GlDisclosureDropdown } from '@gitlab/ui';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import { isSubGroup } from 'ee/security_inventory/utils';
import {
  PROJECT_SECURITY_CONFIGURATION_PATH,
  PROJECT_VULNERABILITY_REPORT_PATH,
  GROUP_VULNERABILITY_REPORT_PATH,
} from 'ee/security_inventory/constants';
import { subgroupsAndProjects } from '../mock_data';

describe('ActionCell', () => {
  let wrapper;

  const mockProject = subgroupsAndProjects.data.group.projects.nodes[0];
  const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ActionCell, {
      propsData: {
        item: {},
        ...props,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);

  const securityConfigPath = (item) => `${item.webUrl}${PROJECT_SECURITY_CONFIGURATION_PATH}`;

  const vulnerabilityPath = (item) =>
    isSubGroup(item)
      ? `${item.webUrl}${GROUP_VULNERABILITY_REPORT_PATH}`
      : `${item.webUrl}${PROJECT_VULNERABILITY_REPORT_PATH}`;

  describe.each`
    type         | item           | viewText           | showToolCoverage
    ${'project'} | ${mockProject} | ${'View project'}  | ${true}
    ${'group'}   | ${mockGroup}   | ${'View subgroup'} | ${false}
  `('when rendering $type item', ({ item, viewText, showToolCoverage }) => {
    beforeEach(() => {
      createComponent({ item });
    });

    it('renders GlDisclosureDropdown', () => {
      expect(findDropdown().exists()).toBe(true);
    });

    it('renders correct dropdown items', () => {
      const items = findDropdown().props('items');
      const expectedLength = showToolCoverage ? 3 : 2;

      expect(items).toHaveLength(expectedLength);

      expect(items[0]).toMatchObject({
        text: viewText,
        href: item.webUrl,
      });

      expect(items[1]).toMatchObject({
        text: 'View vulnerability report',
        href: vulnerabilityPath(item),
      });

      if (showToolCoverage) {
        expect(items[2]).toMatchObject({
          text: 'Manage tool coverage',
          href: securityConfigPath(item),
        });
      }
    });
  });
});
