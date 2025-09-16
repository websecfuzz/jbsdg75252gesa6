import { nextTick } from 'vue';
import { GlExperimentBadge } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTable from 'ee/ai/duo_self_hosted/feature_settings/components/feature_settings_table.vue';
import DuoSelfHostedBatchSettingsUpdater from 'ee/ai/duo_self_hosted/feature_settings/components/batch_settings_updater.vue';
import ModelSelector from 'ee/ai/duo_self_hosted/feature_settings/components/model_selector.vue';
import ModelHeader from 'ee/ai/shared/feature_settings/model_header.vue';

import { mockCodeSuggestionsFeatureSettings, mockAiFeatureSettings } from './mock_data';

describe('FeatureSettingsTable', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(FeatureSettingsTable, {
      propsData: {
        featureSettings: mockCodeSuggestionsFeatureSettings,
        isLoading: false,
        ...props,
      },
    });
  };

  const findFeatureSettingsTable = () => wrapper.findComponent(FeatureSettingsTable);
  const findTableRows = () => findFeatureSettingsTable().findAllComponents('tbody > tr');
  const findTableHeaders = () => findFeatureSettingsTable().findAllComponents('thead > tr');
  const findRowFeatureNameByIdx = (idx) => findTableRows().at(idx).findAll('td').at(0);
  const findModelSelectorByIdx = (idx) => findTableRows().at(idx).findComponent(ModelSelector);
  const findModelBatchSettingsUpdaterByIdx = (idx) =>
    findTableRows().at(idx).findComponent(DuoSelfHostedBatchSettingsUpdater);
  const findBadge = () => wrapper.findComponent(GlExperimentBadge);

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettingsTable().exists()).toBe(true);
  });

  describe('rows', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders row data for each feature setting', () => {
      expect(findTableRows()).toHaveLength(mockCodeSuggestionsFeatureSettings.length);
    });

    it('renders model header', () => {
      const modelHeaderCell = findTableHeaders().at(0).findAll('th').at(1);
      expect(modelHeaderCell.findComponent(ModelHeader).exists()).toBe(true);
    });

    it('renders the feature name', () => {
      expect(findRowFeatureNameByIdx(0).text()).toBe('Code Generation');
      expect(findRowFeatureNameByIdx(1).text()).toBe('Code Completion');
    });

    describe('beta/experiment badges', () => {
      it('renders the beta badge for beta features', () => {
        const betaFeature = mockAiFeatureSettings[4];
        createComponent({ featureSettings: [betaFeature] });

        expect(findBadge().props('type')).toBe('beta');
      });

      it('renders the experiment badge for experiment features', () => {
        const experimentFeature = mockAiFeatureSettings[2];
        createComponent({ featureSettings: [experimentFeature] });

        expect(findBadge().props('type')).toBe('experiment');
      });

      it('does not render the badges for non-beta or non-experimental features', () => {
        createComponent();

        expect(findBadge().exists()).toBe(false);
      });
    });

    it('renders the model select dropdown and passes the correct props', () => {
      [0, 1].forEach((idx) => {
        expect(findModelSelectorByIdx(idx).props()).toEqual({
          aiFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
          batchUpdateIsSaving: false,
        });
      });
    });

    describe('model batch settings updater', () => {
      it('renders the model batch settings updater', () => {
        [0, 1].forEach((idx) => {
          expect(findModelBatchSettingsUpdaterByIdx(idx).props()).toEqual({
            selectedFeatureSetting: mockCodeSuggestionsFeatureSettings[idx],
            aiFeatureSettings: mockCodeSuggestionsFeatureSettings,
          });
        });
      });

      it('does not render the batch settings updater when there is a single feature', () => {
        const featureSetting = mockCodeSuggestionsFeatureSettings[0];

        createComponent({ featureSettings: [featureSetting] });

        expect(findModelBatchSettingsUpdaterByIdx(0).exists()).toBe(false);
      });

      it('handles update-batch-saving-state event correctly', async () => {
        findModelBatchSettingsUpdaterByIdx(0).vm.$emit('update-batch-saving-state', true);
        await nextTick();

        expect(findModelSelectorByIdx(0).props('batchUpdateIsSaving')).toBe(true);
      });
    });
  });
});
