import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogAgentsShow from 'ee/ai/catalog/pages/ai_catalog_agents_show.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import { AI_CATALOG_AGENTS_ROUTE } from 'ee/ai/catalog/router/constants';
import { mockCatalogItemResponse, mockCatalogItemNullResponse, mockAgent } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogAgentsShow', () => {
  let wrapper;
  let mockApollo;
  const agentId = 1;
  const routeParams = { id: agentId };
  const mockRouter = {
    push: jest.fn(),
  };

  const mockCatalogItemQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemResponse);
  const mockCatalogItemNullQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemNullResponse);

  const createComponent = ({ catalogItemQueryHandler = mockCatalogItemQueryHandler } = {}) => {
    mockApollo = createMockApollo([[aiCatalogAgentQuery, catalogItemQueryHandler]]);

    wrapper = shallowMount(AiCatalogAgentsShow, {
      apolloProvider: mockApollo,
      mocks: {
        $route: {
          params: routeParams,
        },
        $router: mockRouter,
      },
    });
  };

  const findHeader = () => wrapper.findComponent(PageHeading);
  const findCatalogItemForm = () => wrapper.findComponent(AiCatalogAgentForm);

  describe('component rendering', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders the page heading with the agent name', () => {
      expect(findHeader().props('heading')).toBe(`Edit agent: ${mockAgent.name}`);
    });
  });

  describe('with agent data', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('fetches item data', () => {
      expect(mockCatalogItemQueryHandler).toHaveBeenCalled();
    });

    it('render edit form', () => {
      expect(findCatalogItemForm().exists()).toBe(true);
    });
  });

  describe('without agent data', () => {
    beforeEach(async () => {
      await createComponent({ catalogItemQueryHandler: mockCatalogItemNullQueryHandler });
    });

    it('fetches list data', () => {
      expect(mockCatalogItemNullQueryHandler).toHaveBeenCalled();
    });

    it('does not render edit form', () => {
      expect(findCatalogItemForm().exists()).toBe(false);
    });

    it('redirect to the agents list page', () => {
      expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_AGENTS_ROUTE });
    });
  });
});
