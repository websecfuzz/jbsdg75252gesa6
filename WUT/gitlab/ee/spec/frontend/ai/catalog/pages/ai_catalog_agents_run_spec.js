import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';

import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogAgentsRun from 'ee/ai/catalog/pages/ai_catalog_agents_run.vue';
import AiCatalogAgentRunForm from 'ee/ai/catalog/components/ai_catalog_agent_run_form.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import { mockAgent, mockCatalogItemResponse } from '../mock_data';

Vue.use(VueApollo);

describe('AiCatalogAgentsRun', () => {
  let wrapper;
  let mockApollo;

  const agentId = '1';

  const mockRouter = {
    back: jest.fn(),
  };
  const mockToast = {
    show: jest.fn(),
  };

  const mockCatalogItemQueryHandler = jest.fn().mockResolvedValue(mockCatalogItemResponse);

  const createComponent = () => {
    mockApollo = createMockApollo([[aiCatalogAgentQuery, mockCatalogItemQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogAgentsRun, {
      apolloProvider: mockApollo,
      mocks: {
        $route: {
          params: { id: agentId },
        },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findRunForm = () => wrapper.findComponent(AiCatalogAgentRunForm);

  beforeEach(async () => {
    await createComponent();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders page heading', () => {
    expect(findPageHeading().props('heading')).toBe(`Run agent: ${mockAgent.name}`);
  });

  it('renders run form', () => {
    expect(findRunForm().exists()).toBe(true);
  });

  it('shows toast with prompt on form submit', () => {
    const mockPrompt = 'Mock prompt';

    findRunForm().vm.$emit('submit', { userPrompt: mockPrompt });

    expect(mockToast.show).toHaveBeenCalledWith(mockPrompt);
  });
});
