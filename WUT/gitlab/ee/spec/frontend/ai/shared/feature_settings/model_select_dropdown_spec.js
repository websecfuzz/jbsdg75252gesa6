import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { selfHostedModelslistItems, modelSelectionListItems } from './mock_data';

describe('ModelSelectDropdown', () => {
  let wrapper;

  const placeholderDropdownText = 'Select model';
  const selectedOption = selfHostedModelslistItems[0];

  const createComponent = ({ props = {} } = {}) => {
    wrapper = extendedWrapper(
      mount(ModelSelectDropdown, {
        propsData: {
          items: selfHostedModelslistItems,
          placeholderDropdownText,
          selectedOption,
          ...props,
        },
      }),
    );
  };

  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);
  const findGLCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownListItems = () => wrapper.findAllByRole('option');
  const findAddModelButton = () => wrapper.findByTestId('add-self-hosted-model-button');
  const findDropdownToggleText = () => wrapper.findByTestId('dropdown-toggle-text');
  const findBetaModelSelectedBadge = () => wrapper.findByTestId('beta-model-selected-badge');
  const findBetaModelDropdownBadges = () => wrapper.findAllByTestId('beta-model-dropdown-badge');
  const findDefaultModelSelectedBadge = () => wrapper.findByTestId('default-model-selected-badge');
  const findDefaultModelDropdownBadge = () => wrapper.findByTestId('default-model-dropdown-badge');

  it('renders the component', () => {
    createComponent();

    expect(findModelSelectDropdown().exists()).toBe(true);
  });

  describe('dropdown toggle text', () => {
    it('renders the placeholder text when no selected option is provided', () => {
      createComponent({
        props: { selectedOption: null },
      });

      expect(findDropdownToggleText().text()).toBe(placeholderDropdownText);
    });

    it('displays the text based on selected option', () => {
      createComponent();

      expect(findDropdownToggleText().text()).toBe(selectedOption.text);
    });
  });

  describe('items', () => {
    it('renders list items', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('items')).toBe(selfHostedModelslistItems);
    });

    it('can handle items with no `releaseState`', () => {
      createComponent({ props: { items: modelSelectionListItems } });

      expect(findGLCollapsibleListbox().props('items')).toBe(modelSelectionListItems);
      expect(findDropdownListItems().at(0).text()).toEqual('Claude Sonnet 3.5 - Anthropic');
      expect(findDropdownListItems().at(1).text()).toEqual('Claude Sonnet 3.7 - Anthropic');
    });

    it('sets a default selected value based on the selected option', () => {
      createComponent({
        props: {
          selectedOption,
        },
      });

      const dropdown = findGLCollapsibleListbox();

      // selected based on selected option prop
      expect(dropdown.props('selected')).toBe(selectedOption.value);
    });

    it('emits select event when an item is selected', async () => {
      createComponent();

      findGLCollapsibleListbox().vm.$emit('select', selectedOption.value);
      await nextTick();

      expect(wrapper.emitted('select')).toStrictEqual([[selectedOption.value]]);
    });
  });

  describe('when isLoading is true', () => {
    it('renders the loading state', () => {
      createComponent({ props: { isLoading: true } });

      expect(findGLCollapsibleListbox().props('loading')).toBe(true);
    });
  });

  describe('when isFeatureSettingDropdown is true', () => {
    beforeEach(() => {
      createComponent({ props: { isFeatureSettingDropdown: true } });
    });

    it('renders compatible models header-text', () => {
      expect(findGLCollapsibleListbox().props('headerText')).toBe('Compatible models');
    });

    it('renders a button to add a self-hosted model', () => {
      expect(findAddModelButton().text()).toBe('Add self-hosted model');
    });
  });

  describe('when isFeatureSettingDropdown is false', () => {
    it('does not render feature setting elements', () => {
      createComponent();

      expect(findGLCollapsibleListbox().props('headerText')).toBe(null);
      expect(findAddModelButton().exists()).toBe(false);
    });
  });

  describe('beta model items', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the beta badge with dropdown options', () => {
      expect(findBetaModelDropdownBadges()).toHaveLength(3);
    });

    it('displays the beta badge when beta option is selected', () => {
      const betaModel = selfHostedModelslistItems[1];

      createComponent({ props: { selectedOption: betaModel } });

      expect(findBetaModelSelectedBadge().exists()).toBe(true);
    });
  });

  describe('default model items', () => {
    it('displays the default model badge with dropdown option', () => {
      createComponent({ props: { items: modelSelectionListItems } });

      const defaultModel = findDropdownListItems().at(3);

      expect(defaultModel.text()).toMatch('GitLab Default (Claude Sonnet 3.7 - Anthropic)');
      expect(findDefaultModelDropdownBadge().exists()).toBe(true);
    });

    it('displays the default model badge when option is selected', () => {
      const defaultModel = { value: '', text: 'GitLab Default (Claude Sonnet 3.7 - Anthropic)' };

      createComponent({
        props: {
          selectedOption: defaultModel,
        },
      });

      expect(findDefaultModelSelectedBadge().exists()).toBe(true);
    });
  });
});
