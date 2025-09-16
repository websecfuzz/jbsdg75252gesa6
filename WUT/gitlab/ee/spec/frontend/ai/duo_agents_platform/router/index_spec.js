import { createRouter } from 'ee/ai/duo_agents_platform/router';
import { AGENTS_PLATFORM_INDEX_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import AgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';

describe('Agents Platform Router', () => {
  let router;
  const baseRoute = '/test-project/-/agents';

  describe('when router is created', () => {
    beforeEach(() => {
      router = createRouter(baseRoute);
    });

    it('configures router with correct base path', () => {
      // Support Vue2 and Vue3
      expect(router.options.base || router.options.history?.base).toBe(baseRoute);
    });

    it('has the correct number of routes', () => {
      expect(router.options.routes).toHaveLength(4);
    });

    describe('when examining the index route', () => {
      let indexRoute;

      beforeEach(() => {
        [indexRoute] = router.options.routes;
      });

      it('has the correct route name', () => {
        expect(indexRoute.name).toBe(AGENTS_PLATFORM_INDEX_ROUTE);
      });

      it('has the correct route path', () => {
        expect(indexRoute.path).toBe('');
      });

      it('has the correct component', () => {
        expect(indexRoute.component).toBe(AgentsPlatformIndex);
      });
    });
  });

  describe('when router is created with custom base', () => {
    const customBase = '/custom-project/-/agents';

    beforeEach(() => {
      router = createRouter(customBase);
    });

    it('uses the custom base path', () => {
      // Support Vue2 and Vue3
      expect(router.options.base || router.options.history?.base).toBe(customBase);
    });
  });

  describe('catchall redirect', () => {
    it('adds the * redirect path as the last route', () => {
      router = createRouter(baseRoute);
      const { routes } = router.options;
      const lastRoute = routes[routes.length - 1];

      // In Vue3, the received result is "/:pathMatch(.*)*"
      expect(lastRoute.path.endsWith('*')).toBe(true);
      expect(lastRoute.redirect).toBe('/');
      expect(lastRoute.name).toBeUndefined();
    });
  });
});
