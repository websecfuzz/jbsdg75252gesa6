import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogApp from 'ee/ai/catalog/ai_catalog_app.vue';
import { AI_CATALOG_AGENTS_NEW_ROUTE } from 'ee/ai/catalog/router/constants';

describe('AiCatalogApp', () => {
  let wrapper;

  const mockRouter = {
    push: jest.fn(),
  };

  beforeEach(() => {
    wrapper = shallowMountExtended(AiCatalogApp, {
      mocks: {
        $router: mockRouter,
      },
      stubs: {
        'router-view': true,
      },
    });
  });

  it('renders the New Agent button', () => {
    const button = wrapper.findComponent(GlButton);
    expect(button.exists()).toBe(true);

    expect(button.props('to')).toEqual({ name: AI_CATALOG_AGENTS_NEW_ROUTE });
  });
});
