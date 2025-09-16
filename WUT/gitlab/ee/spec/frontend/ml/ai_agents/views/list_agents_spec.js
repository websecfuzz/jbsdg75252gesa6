import { GlExperimentBadge } from '@gitlab/ui';
import { RouterLinkStub as RouterLink } from '@vue/test-utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListAgents from 'ee/ml/ai_agents/views/list_agents.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import AgentList from 'ee/ml/ai_agents/components/agent_list.vue';

let wrapper;

const createWrapper = () => {
  wrapper = shallowMountExtended(ListAgents, {
    stubs: {
      RouterLink,
    },
  });
};

const findTitleArea = () => wrapper.findComponent(TitleArea);
const findCreateButton = () => findTitleArea().findComponent(RouterLink);
const findBadge = () => wrapper.findComponent(GlExperimentBadge);
const findAgentList = () => wrapper.findComponent(AgentList);

describe('ee/ml/ai_agents/views/list_agents', () => {
  beforeEach(() => createWrapper());

  it('shows the title', () => {
    expect(findTitleArea().text()).toContain('AI Agents');
  });

  it('displays the experiment badge', () => {
    expect(findBadge().props('type')).toBe('experiment');
  });

  it('shows create agent button', () => {
    expect(findCreateButton().props('to')).toMatchObject({
      name: 'create',
    });
  });

  it('shows the agent list', () => {
    expect(findAgentList().exists()).toBe(true);
  });
});
