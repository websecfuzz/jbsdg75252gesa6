import { GlCollapsibleListbox, GlListboxItem, GlLoadingIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import GroupSelect from 'ee/boards/components/group_select.vue';
import subgroupsQuery from '~/boards/graphql/sub_groups.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockGroup0, mockGroupsResponse } from '../mock_data';

Vue.use(VueApollo);

describe('GroupSelect component', () => {
  let wrapper;
  let mockApollo;

  const findLabel = () => wrapper.findByTestId('header-label');
  const findGlDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGlDropdownLoadingIcon = () =>
    findGlDropdown().find('button:first-child').findComponent(GlLoadingIcon);
  const findGlSearchBoxByType = () => wrapper.findByTestId('listbox-search-input');
  const findGlDropdownItems = () => wrapper.findAllComponents(GlListboxItem);
  const findFirstGlDropdownItem = () => findGlDropdownItems().at(0);
  const findInMenuLoadingIcon = () => wrapper.findByTestId('listbox-infinite-scroll-loader');

  const groupsQueryHandler = jest.fn().mockResolvedValue(mockGroupsResponse());
  const emptyGroupsQueryHandler = jest.fn().mockResolvedValue(mockGroupsResponse([]));

  const createWrapper = ({ queryHandler = groupsQueryHandler, selectedGroup = {} } = {}) => {
    mockApollo = createMockApollo([[subgroupsQuery, queryHandler]]);
    wrapper = extendedWrapper(
      mount(GroupSelect, {
        apolloProvider: mockApollo,
        propsData: {
          selectedGroup,
        },
        provide: {
          groupId: 1,
          fullPath: 'gitlab-org',
        },
      }),
    );
  };

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays a loading icon while descendant groups are being fetched', async () => {
      expect(findGlDropdownLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findGlDropdownLoadingIcon().exists()).toBe(false);
      expect(groupsQueryHandler).toHaveBeenCalled();
    });

    it('displays a header title', () => {
      expect(findLabel().text()).toBe('Groups');
    });

    it('renders a default dropdown text', () => {
      createWrapper();

      expect(findGlDropdown().exists()).toBe(true);
      expect(findGlDropdown().text()).toContain('Loading groups');
    });
  });

  describe('when dropdown menu is open', () => {
    describe('by default', () => {
      beforeEach(async () => {
        createWrapper();
        await waitForPromises();
      });

      it('shows GlSearchBoxByType with default attributes', () => {
        expect(findGlSearchBoxByType().exists()).toBe(true);
      });

      it("displays the fetched groups's name", () => {
        expect(findFirstGlDropdownItem().exists()).toBe(true);
        expect(findFirstGlDropdownItem().text()).toContain(mockGroup0.name);
      });

      it('does not render loading icon in the menu', () => {
        expect(findInMenuLoadingIcon().exists()).toBe(false);
      });
    });

    describe('when no subgroups are being returned', () => {
      it('renders parent group only', async () => {
        createWrapper({ queryHandler: emptyGroupsQueryHandler });
        await waitForPromises();

        expect(findGlDropdownItems()).toHaveLength(1);
        expect(findFirstGlDropdownItem().text()).toContain(mockGroup0.name);
      });
    });

    describe('when a group is selected', () => {
      it('renders the name of the selected group', () => {
        createWrapper({ selectedGroup: mockGroup0 });

        expect(findGlDropdown().props('toggleText')).toBe(mockGroup0.name);
      });
    });
  });
});
