import { GlCard, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoModelsConfigurationInfoCard from 'ee/ai/settings/components/duo_models_configuration_info_card.vue';

describe('DuoModelsConfigurationInfoCard', () => {
  let wrapper;

  const duoModelsConfigurationProps = {
    header: 'Models info card header',
    description: 'Models info card description',
    buttonText: 'Configure models button text',
    path: '/admin/ai/duo_self_hosted',
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(DuoModelsConfigurationInfoCard, {
      propsData: {
        duoModelsConfigurationProps,
        ...props,
      },
    });
  };

  const findCard = () => wrapper.findAllComponents(GlCard);
  const findInfoCardHeader = () => wrapper.find('h2');
  const findInfoCardSecondaryHeader = () =>
    wrapper.findByTestId('model-configuration-card-secondary-header');
  const findInfoCardDescription = () =>
    wrapper.findByTestId('model-configuration-card-description');
  const findConfigurationButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  it('renders info card and correct copy', () => {
    expect(findCard().exists()).toBe(true);
    expect(findInfoCardHeader().text()).toContain('Models info card header');
    expect(findInfoCardSecondaryHeader().text()).toContain('Configure AI features');
    expect(findInfoCardDescription().text()).toMatch('Models info card description');
  });

  it('renders a CTA button', () => {
    expect(findConfigurationButton().text()).toBe('Configure models button text');
    expect(findConfigurationButton().attributes('to')).toBe('/admin/ai/duo_self_hosted');
  });
});
