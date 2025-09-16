import { GlBadge, GlMarkdown, GlAvatar, GlDisclosureDropdownItem } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';

const mockRoute = '/mock-route';

describe('AiCatalogListItem', () => {
  let wrapper;

  const mockRouter = {
    resolve: jest.fn().mockReturnValue({
      route: {
        path: mockRoute,
      },
    }),
  };

  const mockItem = {
    id: 'gid://gitlab/Ai::Catalog::Item/1',
    name: 'Test AI Agent',
    itemType: 'AGENT',
    description: 'A helpful AI assistant for testing purposes',
  };

  const createComponent = (item = mockItem) => {
    wrapper = shallowMountExtended(AiCatalogListItem, {
      propsData: {
        item,
      },
      mocks: {
        $options: {
          routes: {
            show: '/agents/:id',
            run: '/agents/:id/run',
          },
        },

        $router: mockRouter,
      },
    });
  };

  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findBadges = () => wrapper.findAllComponents(GlBadge);
  const findTypeBadge = () => findBadges().at(0);
  const findMarkdown = () => wrapper.findComponent(GlMarkdown);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the list item container with correct attributes', () => {
      const listItem = wrapper.findByTestId('ai-catalog-list-item');

      expect(listItem.exists()).toBe(true);
      expect(listItem.element.tagName).toBe('LI');
    });

    it('renders avatar with correct props', () => {
      const avatar = findAvatar();

      expect(avatar.exists()).toBe(true);
      expect(avatar.props('alt')).toBe('Test AI Agent avatar');
      expect(avatar.props('entityName')).toBe('Test AI Agent');
      expect(avatar.props('size')).toBe(48);
    });

    it('displays type badge with correct variant and text', () => {
      const typeBadge = findTypeBadge();

      expect(typeBadge.exists()).toBe(true);
      expect(typeBadge.props('variant')).toBe('neutral');
      expect(typeBadge.text()).toBe('agent');
    });

    it('displays three actions in a disclosure dropdown', () => {
      const items = findDisclosureDropdownItems();

      expect(items).toHaveLength(3);
      expect(items.at(0).text()).toBe('Run');
      expect(items.at(0).attributes('to')).toBe(mockRoute);
      expect(items.at(1).text()).toBe('Edit');
      expect(items.at(1).attributes('to')).toBe(mockRoute);
      expect(items.at(2).text()).toBe('Delete (Coming soon)');
      expect(items.at(2).attributes('variant')).toBe('danger');
    });

    it('displays description', () => {
      const markdown = findMarkdown();

      expect(markdown.exists()).toBe(true);
      expect(markdown.text()).toBe('A helpful AI assistant for testing purposes');
      expect(markdown.props('compact')).toBe(true);
    });
  });
});
