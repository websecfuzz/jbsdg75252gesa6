import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlPopover, GlLink } from '@gitlab/ui';
import ScopedGroupsDropdown from 'ee/security_orchestration/components/shared/scoped_groups_dropdown.vue';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';
import getSppLinkedProjectGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createMockGroups } from 'ee_jest/security_orchestration/mocks/mock_data';

describe('ScopedGroupsDropdown', () => {
  let wrapper;
  let requestHandler;

  const groups = [
    {
      id: '1',
      name: 'group1',
      fullPath: 'fullPath1',
      descendantGroups: { nodes: [] },
      fullName: 'fullName1',
      avatarUrl: 'avatarUrl1',
    },
    {
      id: '2',
      name: 'group2',
      fullPath: 'fullPath2',
      descendantGroups: { nodes: [] },
      fullName: 'fullName2',
      avatarUrl: 'avatarUrl2',
    },
  ];

  const groupsIds = groups.map(({ id }) => id);

  const mapItems = ({ id, name, fullPath }) => ({ text: name, value: id, fullPath });

  const moreGroups = createMockGroups(4);

  const groupsHandler = (nodes = moreGroups) =>
    jest.fn().mockResolvedValueOnce({
      data: {
        groups: {
          nodes,
          pageInfo: {},
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([
      [getSppLinkedProjectGroups, requestHandler.linkedGroupsHandler],
      [getGroups, requestHandler.groupsHandler],
    ]);
  };

  const defaultHandler = {
    linkedGroupsHandler: mockLinkedSppItemsResponse({ groups }),
    groupsHandler: groupsHandler(),
  };

  const createComponent = ({
    propsData = {},
    handler = defaultHandler,
    provide = {},
    stubs = {},
  } = {}) => {
    wrapper = shallowMountExtended(ScopedGroupsDropdown, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        fullPath: 'gitlab-org',
        ...propsData,
      },
      stubs,
      provide: { designatedAsCsp: false, ...provide },
    });
  };

  const findDropdown = () => wrapper.findComponent(BaseItemsDropdown);
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('loading items', () => {
    it('renders loading state', () => {
      createComponent();
      expect(findDropdown().props('loading')).toBe(true);
    });

    it('emits error if loading fails', async () => {
      createComponent({
        handler: jest.fn().mockRejectedValue({}),
      });

      await waitForPromises();
      expect(wrapper.emitted('linked-items-query-error')).toHaveLength(1);
      expect(wrapper.emitted('loaded')).toEqual([[[]]]);
    });
  });

  describe('groups', () => {
    it('renders default dropdown state', async () => {
      createComponent();
      await waitForPromises();
      expect(findDropdown().props('headerText')).toBe('Select groups');
      expect(findDropdown().props('itemTypeName')).toBe('groups');
      expect(findDropdown().props('loading')).toBe(false);
    });

    describe('csp group', () => {
      beforeEach(async () => {
        createComponent({ provide: { designatedAsCsp: true } });
        await waitForPromises();
      });

      it('requests groups', () => {
        expect(findDropdown().props('items')).toEqual(moreGroups.map(mapItems));
      });

      it('makes a query to fetch more groups', () => {
        findDropdown().vm.$emit('bottom-reached');

        expect(requestHandler.groupsHandler).toHaveBeenCalledTimes(2);
        expect(requestHandler.groupsHandler).toHaveBeenNthCalledWith(2, {
          after: undefined,
          search: '',
        });
      });
    });

    describe('non-csp group', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('requests linked groups', () => {
        expect(findDropdown().props('items')).toEqual(groups.map(mapItems));
      });

      it('makes a query to fetch more groups', () => {
        findDropdown().vm.$emit('bottom-reached');

        expect(requestHandler.linkedGroupsHandler).toHaveBeenCalledTimes(2);
        expect(requestHandler.linkedGroupsHandler).toHaveBeenNthCalledWith(2, {
          fullPath: 'gitlab-org',
          after: null,
          includeParentDescendants: false,
          search: '',
          topLevelOnly: false,
        });
      });
    });
  });

  describe('selected items', () => {
    it('renders selected items', async () => {
      createComponent({
        propsData: {
          selected: groupsIds,
        },
        stubs: {
          BaseItemsDropdown,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(groupsIds);
      expect(findDropdown().findComponent(GlCollapsibleListbox).props('toggleText')).toEqual(
        'All groups',
      );
    });
  });

  describe('search', () => {
    it.each([groups[0].name, `${groups[0].name}   `])(
      'searches by text and trims spaces',
      async (searchValue) => {
        createComponent();

        await waitForPromises();

        await findDropdown().vm.$emit('search', searchValue);
        expect(findDropdown().props('items')).toEqual([groups[0]].map(mapItems));
      },
    );

    it('searches by fullPath', async () => {
      createComponent();

      await waitForPromises();

      await findDropdown().vm.$emit('search', groups[0].fullPath);
      expect(findDropdown().props('items')).toEqual([groups[0]].map(mapItems));
    });
  });

  describe('popover', () => {
    it('does not render popover when groups exist', async () => {
      createComponent();
      await waitForPromises();

      expect(findPopover().exists()).toBe(false);
      expect(wrapper.emitted('loaded')).toEqual([[groups]]);
    });

    it('does not render popover when there are no groups but loading is in progress', () => {
      createComponent({
        handler: mockLinkedSppItemsResponse({ groups: [] }),
      });

      expect(findPopover().exists()).toBe(false);
      expect(findDropdown().props('disabled')).toBe(false);
    });

    it('renders popover when there are no groups', async () => {
      createComponent({
        handler: mockLinkedSppItemsResponse({ groups: [] }),
      });
      await waitForPromises();

      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props('show')).toBe(true);
      expect(findDropdown().props('disabled')).toBe(true);
      expect(findPopover().text()).toContain('No linked groups');
      expect(wrapper.emitted('loaded')).toEqual([[[]]]);
      expect(findPopover().findComponent(GlLink).attributes('href')).toBe(
        '/help/user/application_security/policies/security_policy_projects.md',
      );
    });
  });

  describe('include descendants', () => {
    it('queries descendant groups', () => {
      createComponent({
        propsData: {
          includeDescendants: true,
        },
      });

      expect(requestHandler.linkedGroupsHandler).toHaveBeenCalledWith({
        after: '',
        fullPath: 'gitlab-org',
        includeParentDescendants: true,
        search: '',
        topLevelOnly: false,
      });
    });
  });

  describe('select items', () => {
    it('selects items and emits selected event', async () => {
      createComponent();
      await waitForPromises();
      findDropdown().vm.$emit('select', [groups[0].id]);

      expect(wrapper.emitted('select')).toEqual([[[groups[0]]]]);
    });
  });

  describe('missing groups', () => {
    it('loads groups if they were selected but missing from first loaded page', async () => {
      createComponent({
        propsData: {
          selected: [groupsIds[0], moreGroups[2].id.toString()],
        },
      });
      await waitForPromises();

      expect(requestHandler.groupsHandler).toHaveBeenCalledTimes(1);
      expect(requestHandler.groupsHandler).toHaveBeenCalledWith({
        topLevelOnly: false,
        ids: ['3'],
        after: '',
      });
    });
  });
});
