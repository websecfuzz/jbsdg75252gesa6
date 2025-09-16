import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import FeatureSettings from 'ee/ai/model_selection/feature_settings.vue';

import {
  mockCodeSuggestionsFeatureSettings,
  mockDuoChatFeatureSettings,
  mockMergeRequestFeatureSettings,
  mockIssueFeatureSettings,
  mockOtherDuoFeaturesSettings,
  mockAiFeatureSettings,
} from './mock_data';

describe('FeatureSettings', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(FeatureSettings, {
      propsData: {
        featureSettings: mockAiFeatureSettings,
        isLoading: false,
        ...props,
      },
    });
  };

  const findFeatureSettings = () => wrapper.findComponent(FeatureSettings);
  const findAllSettingsBlock = () => wrapper.findAllComponents(FeatureSettingsBlock);
  const findAllSettingsDescriptions = () => wrapper.findAllComponents(GlSprintf);
  const findDuoChatTable = () => wrapper.findByTestId('duo-chat-table');
  const findCodeSuggestionsTable = () => wrapper.findByTestId('code-suggestions-table');
  const findOtherDuoFeaturesTable = () => wrapper.findByTestId('other-duo-features-table');
  const findDuoIssuesTable = () => wrapper.findByTestId('duo-issues-table');
  const findDuoMergeRequestTable = () => wrapper.findByTestId('duo-merge-requests-table');

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettings().exists()).toBe(true);
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to `FeatureSettingsTableRows`', () => {
      createComponent({ props: { isLoading: true } });

      expect(findCodeSuggestionsTable().props('isLoading')).toBe(true);
      expect(findDuoChatTable().props('isLoading')).toBe(true);
      expect(findDuoMergeRequestTable().props('isLoading')).toBe(true);
      expect(findDuoIssuesTable().props('isLoading')).toBe(true);
      expect(findOtherDuoFeaturesTable().props('isLoading')).toBe(true);
    });
  });

  describe('sections', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders Code Suggestions section', () => {
      expect(findAllSettingsBlock().at(0).props('title')).toBe('Code Suggestions');
      expect(findAllSettingsDescriptions().at(0).attributes('message')).toContain(
        'Assists developers by generating and completing code in real-time.',
      );
      expect(findCodeSuggestionsTable().props('featureSettings')).toEqual(
        mockCodeSuggestionsFeatureSettings,
      );
    });

    it('renders Duo Chat section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(1).props('title')).toBe('GitLab Duo Chat');
      expect(findAllSettingsDescriptions().at(1).attributes('message')).toContain(
        'An AI assistant that helps users accelerate software development using real-time conversational AI',
      );
      expect(findDuoChatTable().props('featureSettings')).toEqual(mockDuoChatFeatureSettings);
    });

    it('renders Duo Merge Request section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(2).props('title')).toBe('GitLab Duo for merge requests');
      expect(findAllSettingsDescriptions().at(2).attributes('message')).toContain(
        'AI-native features that help users accomplish tasks during the lifecycle of a merge request.',
      );
      expect(findDuoMergeRequestTable().props('featureSettings')).toEqual(
        mockMergeRequestFeatureSettings,
      );
    });

    it('renders Duo issues section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(3).props('title')).toBe('GitLab Duo for issues');
      expect(findAllSettingsDescriptions().at(3).attributes('message')).toContain(
        'An AI-native feature that generates a summary of discussions on an issue.',
      );
      expect(findDuoIssuesTable().props('featureSettings')).toEqual(mockIssueFeatureSettings);
    });

    it('renders Other GitLab Duo features section', () => {
      createComponent();

      expect(findAllSettingsBlock().at(4).props('title')).toBe('Other GitLab Duo features');
      expect(findAllSettingsDescriptions().at(4).attributes('message')).toContain(
        'AI-native features that support users outside of Chat or Code Suggestions.',
      );
      expect(findOtherDuoFeaturesTable().props('featureSettings')).toEqual(
        mockOtherDuoFeaturesSettings,
      );
    });
  });
});
