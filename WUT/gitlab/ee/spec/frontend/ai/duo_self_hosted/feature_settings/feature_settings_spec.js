import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';

import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import FeatureSettings from 'ee/ai/duo_self_hosted/feature_settings/components/feature_settings.vue';
import getAiFeatureSettingsQuery from 'ee/ai/duo_self_hosted/feature_settings/graphql/queries/get_ai_feature_settings.query.graphql';
import BetaFeaturesAlert from 'ee/ai/duo_self_hosted/feature_settings/components/beta_features_alert.vue';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';

import {
  mockAiFeatureSettings,
  mockDuoChatFeatureSettings,
  mockCodeSuggestionsFeatureSettings,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('FeatureSettings', () => {
  let wrapper;

  const duoConfigurationSettingsPath = '/admin/gitlab_duo/configuration';
  const getAiFeatureSettingsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiFeatureSettings: {
        nodes: mockAiFeatureSettings,
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[getAiFeatureSettingsQuery, getAiFeatureSettingsSuccessHandler]],
    injectedProps = {},
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);

    wrapper = shallowMountExtended(FeatureSettings, {
      apolloProvider: mockApollo,
      provide: {
        betaModelsEnabled: true,
        duoConfigurationSettingsPath,
        ...injectedProps,
      },
    });
  };

  const findFeatureSettings = () => wrapper.findComponent(FeatureSettings);
  const findDuoChatTable = () => wrapper.findByTestId('duo-chat-table');
  const findCodeSuggestionsTable = () => wrapper.findByTestId('code-suggestions-table');
  const findOtherDuoFeaturesTable = () => wrapper.findByTestId('other-duo-features-table');
  const findDuoMergeRequestTable = () => wrapper.findByTestId('duo-merge-requests-table');
  const findDuoIssuesTable = () => wrapper.findByTestId('duo-issues-table');
  const findAllSettingsBlock = () => wrapper.findAllComponents(FeatureSettingsBlock);
  const findAllSettingsDescriptions = () => wrapper.findAllComponents(GlSprintf);
  const findBetaAlert = () => wrapper.findComponent(BetaFeaturesAlert);

  beforeEach(async () => {
    createComponent();

    await waitForPromises();
  });

  it('renders the component', () => {
    expect(findFeatureSettings().exists()).toBe(true);
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to FeatureSettingsTable', () => {
      createComponent();

      [findCodeSuggestionsTable, findDuoChatTable].forEach((findTableFn) => {
        expect(findTableFn().props('isLoading')).toBe(true);
      });
    });
  });

  describe('when feature settings query is successful', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    describe.each`
      section                         | index | expectedTitle                      | expectedDescription                                                                                      | findSectionTableFn           | expectedFeatureSettings
      ${'Code Suggestions'}           | ${0}  | ${'Code Suggestions'}              | ${'Assists developers by generating and completing code in real-time.'}                                  | ${findCodeSuggestionsTable}  | ${[['code_generations', 'GA'], ['code_completions', 'GA']]}
      ${'Duo Chat'}                   | ${1}  | ${'GitLab Duo Chat'}               | ${'An AI assistant that helps users accelerate software development using real-time conversational AI.'} | ${findDuoChatTable}          | ${[['duo_chat', 'GA'], ['duo_chat_explain_code', 'BETA'], ['duo_chat_troubleshoot_job', 'EXPERIMENT']]}
      ${'Duo merge request features'} | ${2}  | ${'GitLab Duo for merge requests'} | ${'AI-native features that help users accomplish tasks during the lifecycle of a merge request.'}        | ${findDuoMergeRequestTable}  | ${[['summarize_review', 'BETA'], ['generate_commit_message', 'BETA']]}
      ${'Duo issues'}                 | ${3}  | ${'GitLab Duo for issues'}         | ${'An AI-native feature that generates a summary of discussions on an issue.'}                           | ${findDuoIssuesTable}        | ${[['duo_chat_summarize_comments', 'BETA']]}
      ${'Other Duo features'}         | ${4}  | ${'Other GitLab Duo features'}     | ${'AI-native features that support users outside of Chat or Code Suggestions.'}                          | ${findOtherDuoFeaturesTable} | ${[['glab_ask_git_command', 'BETA']]}
    `(
      '$section',
      ({
        index,
        expectedTitle,
        expectedDescription,
        findSectionTableFn,
        expectedFeatureSettings,
      }) => {
        it('renders section and table', () => {
          expect(findAllSettingsBlock().at(index).props('title')).toBe(expectedTitle);
          expect(findAllSettingsDescriptions().at(index).attributes('message')).toContain(
            expectedDescription,
          );
          expect(findSectionTableFn().exists()).toBe(true);
        });

        it('passes sorted feature settings by release state as table props', () => {
          expect(
            findSectionTableFn()
              .props('featureSettings')
              .map((fs) => [fs.feature, fs.releaseState]),
          ).toEqual(expectedFeatureSettings);
        });
      },
    );

    it('does not render section when there are no feature settings to show', async () => {
      const featureSettingsExcludingOtherDuo = [
        ...mockDuoChatFeatureSettings,
        ...mockCodeSuggestionsFeatureSettings,
      ];
      const getFeatureSettingsExcludingOtherDuoSuccessHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            nodes: featureSettingsExcludingOtherDuo,
            errors: [],
          },
        },
      });

      createComponent({
        apolloHandlers: [
          [getAiFeatureSettingsQuery, getFeatureSettingsExcludingOtherDuoSuccessHandler],
        ],
      });
      await waitForPromises();

      expect(findAllSettingsBlock()).toHaveLength(2);
      expect(findOtherDuoFeaturesTable().exists()).toBe(false);
    });
  });

  describe('when beta features are enabled', () => {
    it('does not display a beta models info alert', () => {
      expect(findBetaAlert().exists()).toBe(false);
    });
  });

  describe('when beta features are disabled', () => {
    it('displays a beta models info alert', () => {
      createComponent({
        injectedProps: {
          betaModelsEnabled: false,
        },
      });

      expect(findBetaAlert().props('duoConfigurationSettingsPath')).toBe(
        duoConfigurationSettingsPath,
      );
    });
  });

  describe('when the API request is unsuccessful', () => {
    describe('due to a general error', () => {
      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [[getAiFeatureSettingsQuery, jest.fn().mockRejectedValue('ERROR')]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });

    describe('due to a business logic error', () => {
      const getAiFeatureSettingsErrorHandler = jest.fn().mockResolvedValue({
        data: {
          aiFeatureSettings: {
            errors: ['An error occured'],
          },
        },
      });

      it('displays an error message for feature settings', async () => {
        createComponent({
          apolloHandlers: [[getAiFeatureSettingsQuery, getAiFeatureSettingsErrorHandler]],
        });

        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading the AI feature settings. Please try again.',
          }),
        );
      });
    });
  });
});
