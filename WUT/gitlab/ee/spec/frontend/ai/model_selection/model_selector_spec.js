import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ModelSelector from 'ee/ai/model_selection/model_selector.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import updateAiNamespaceFeatureSettingsMutation from 'ee/ai/model_selection/graphql/update_ai_namespace_feature_settings.mutation.graphql';
import getAiNamespaceFeatureSettingsQuery from 'ee/ai/model_selection/graphql/get_ai_namepace_feature_settings.query.graphql';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

import { mockDuoChatFeatureSettings } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('ModelSelector', () => {
  let wrapper;

  const aiFeatureSetting = mockDuoChatFeatureSettings[0];
  const groupId = 'gid://gitlab/Group/1';
  const mockToastShow = jest.fn();

  const updateAiNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceUpdate: {
        errors: [],
      },
    },
  });

  const getAiNamespaceFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiModelSelectionNamespaceSettings: {
        nodes: mockDuoChatFeatureSettings,
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [
      [updateAiNamespaceFeatureSettingsMutation, updateAiNamespaceFeatureSettingsSuccessHandler],
      [getAiNamespaceFeatureSettingsQuery, getAiNamespaceFeatureSettingsSuccessHandler],
    ],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = extendedWrapper(
      shallowMount(ModelSelector, {
        apolloProvider: mockApollo,
        propsData: {
          aiFeatureSetting,
          batchUpdateIsSaving: false,
          ...props,
        },
        provide: {
          groupId,
        },
        mocks: {
          $toast: {
            show: mockToastShow,
          },
        },
      }),
    );
  };

  const findModelSelector = () => wrapper.findComponent(ModelSelector);
  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);

  it('renders the component', () => {
    createComponent();

    expect(findModelSelector().exists()).toBe(true);
  });

  describe('loading state', () => {
    it('passes corect loading state to `ModelSelectDropdown` while saving', async () => {
      createComponent();

      await findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });

    it('passes corect loading state to `ModelSelectDropdown` while batch saving', () => {
      createComponent({ props: { batchUpdateIsSaving: true } });

      expect(findModelSelectDropdown().props('isLoading')).toBe(true);
    });
  });

  describe('.listItems', () => {
    it('contains a list of models, including a default model option', () => {
      createComponent();

      expect(findModelSelectDropdown().props('items')).toEqual([
        { value: 'claude_sonnet_3_7_20250219', text: 'Claude Sonnet 3.7 - Anthropic' },
        { value: 'claude_3_5_sonnet_20240620', text: 'Claude Sonnet 3.5 - Anthropic' },
        { value: 'claude_3_haiku_20240307', text: 'Claude Haiku 3 - Anthropic' },
        { value: '', text: 'GitLab Default (Claude Sonnet 3.7 - Anthropic)' },
      ]);
    });
  });

  describe('updating the feature setting', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls the update mutation with correct input', () => {
      findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

      expect(updateAiNamespaceFeatureSettingsSuccessHandler).toHaveBeenCalledWith({
        input: {
          features: ['DUO_CHAT'],
          groupId: 'gid://gitlab/Group/1',
          offeredModelRef: 'claude_3_5_sonnet_20240620',
        },
      });
    });

    describe('when the update succeeds', () => {
      it('triggers a success toast', async () => {
        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(mockToastShow).toHaveBeenCalledWith(
          'Successfully updated GitLab Duo Chat / General Chat',
        );
      });

      it('updates the selected option', async () => {
        const mockSelectedModelId = 'claude_3_5_sonnet_20240620';
        const modelSelectionDropdown = findModelSelectDropdown();

        expect(modelSelectionDropdown.props('selectedOption')).toStrictEqual({
          value: '',
          text: 'GitLab Default (Claude Sonnet 3.7 - Anthropic)',
        });

        modelSelectionDropdown.vm.$emit('select', mockSelectedModelId);
        await waitForPromises();

        await wrapper.setProps({
          aiFeatureSetting: {
            ...aiFeatureSetting,
            selectedModel: { ref: mockSelectedModelId },
          },
        });

        expect(modelSelectionDropdown.props('selectedOption')).toStrictEqual({
          value: mockSelectedModelId,
          text: 'Claude Sonnet 3.5 - Anthropic',
        });
      });

      it('refetches namespace feature settings data', async () => {
        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(getAiNamespaceFeatureSettingsSuccessHandler).toHaveBeenCalled();
      });
    });

    describe('when an update fails', () => {
      const updateAiNamespaceFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiModelSelectionNamespaceUpdate: {
            aiFeatureSettings: null,
            errors: ['Model selection not available'],
          },
        },
      });

      beforeEach(() => {
        createComponent({
          apolloHandlers: [
            [
              updateAiNamespaceFeatureSettingsMutation,
              updateAiNamespaceFeatureSettingsErrorHandler,
            ],
            [getAiNamespaceFeatureSettingsQuery, getAiNamespaceFeatureSettingsSuccessHandler],
          ],
        });
      });

      it('does not update the selected option', async () => {
        const modelSelectionDropdown = findModelSelectDropdown();

        modelSelectionDropdown.vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(modelSelectionDropdown.props('selectedOption')).toStrictEqual({
          value: '',
          text: 'GitLab Default (Claude Sonnet 3.7 - Anthropic)',
        });
      });

      it('triggers an error message', async () => {
        findModelSelectDropdown().vm.$emit('select', 'claude_3_5_sonnet_20240620');

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Model selection not available',
          }),
        );
      });
    });
  });
});
