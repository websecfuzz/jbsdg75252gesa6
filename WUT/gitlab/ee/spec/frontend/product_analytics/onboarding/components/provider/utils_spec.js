import { InMemoryCache } from '@apollo/client/cache';

import getProductAnalyticsProjectSettings from 'ee/product_analytics/graphql/queries/get_product_analytics_project_settings.query.graphql';
import {
  projectSettingsValidator,
  getProjectSettingsValidationErrors,
  updateProjectSettingsApolloCache,
} from 'ee/product_analytics/onboarding/components/providers/utils';
import {
  getPartialProjectLevelAnalyticsProviderSettings,
  TEST_PROJECT_FULL_PATH,
  TEST_PROJECT_ID,
} from 'ee_jest/product_analytics/mock_data';

describe('product analytics onboarding provider utils', () => {
  describe('projectSettingsValidator', () => {
    const validProp = {
      productAnalyticsConfiguratorConnectionString: 'https://test:test@configurator.example.com',
      productAnalyticsDataCollectorHost: 'https://collector.example.com',
      cubeApiBaseUrl: 'https://cube.example.com',
      cubeApiKey: '123-some-cube-key',
    };
    const { cubeApiKey, ...propMissingCube } = validProp;

    const testCases = [
      ['valid settings', validProp, true],
      ['null value', { ...validProp, cubeApiKey: null }, true],
      ['missing property', propMissingCube, false],
      ['unexpected property', { ...validProp, someUnexpectedProp: 'test' }, false],
      ['invalid value type', { ...validProp, cubeApiKey: 123 }, false],
      ['empty object', {}, false],
    ];

    it.each(testCases)('%s', (_, prop, expected) => {
      expect(projectSettingsValidator(prop)).toBe(expected);
    });
  });

  describe('getProjectSettingsValidationErrors', () => {
    const validPayload = {
      productAnalyticsConfiguratorConnectionString: 'https://configurator.example.com',
      productAnalyticsDataCollectorHost: 'https://collector.example.com',
      cubeApiBaseUrl: 'https://cube.example.com',
      cubeApiKey: 'abc',
    };

    it.each`
      payload                                                                     | expected
      ${{ productAnalyticsConfiguratorConnectionString: 'not-a-url' }}            | ${{ productAnalyticsConfiguratorConnectionString: 'Enter a valid URL' }}
      ${{ productAnalyticsConfiguratorConnectionString: '/not/an/absolute/url' }} | ${{ productAnalyticsConfiguratorConnectionString: 'Enter a valid URL' }}
      ${{ productAnalyticsConfiguratorConnectionString: '' }}                     | ${{ productAnalyticsConfiguratorConnectionString: 'This field is required' }}
      ${{ productAnalyticsDataCollectorHost: 'not-a-url' }}                       | ${{ productAnalyticsDataCollectorHost: 'Enter a valid URL' }}
      ${{ productAnalyticsDataCollectorHost: '/not/an/absolute/url' }}            | ${{ productAnalyticsDataCollectorHost: 'Enter a valid URL' }}
      ${{ productAnalyticsDataCollectorHost: '' }}                                | ${{ productAnalyticsDataCollectorHost: 'This field is required' }}
      ${{ cubeApiBaseUrl: 'not-a-url' }}                                          | ${{ cubeApiBaseUrl: 'Enter a valid URL' }}
      ${{ cubeApiBaseUrl: '/not/an/absolute/url' }}                               | ${{ cubeApiBaseUrl: 'Enter a valid URL' }}
      ${{ cubeApiBaseUrl: '' }}                                                   | ${{ cubeApiBaseUrl: 'This field is required' }}
      ${{ cubeApiKey: '' }}                                                       | ${{ cubeApiKey: 'This field is required' }}
      ${{}}                                                                       | ${{}}
    `('returns $expected for $payload', ({ expected, payload }) => {
      expect(getProjectSettingsValidationErrors({ ...validPayload, ...payload })).toEqual(expected);
    });
  });

  describe('updateProjectSettingsApolloCache', () => {
    let apolloCache;
    const projectPath = TEST_PROJECT_FULL_PATH;
    const existingSettings = getPartialProjectLevelAnalyticsProviderSettings();

    beforeEach(() => {
      apolloCache = new InMemoryCache();

      apolloCache.writeQuery({
        query: getProductAnalyticsProjectSettings,
        variables: { projectPath },
        data: {
          project: {
            id: TEST_PROJECT_ID,
            productAnalyticsSettings: existingSettings,
            __typename: 'Project',
          },
        },
      });
    });

    it.each([
      {
        productAnalyticsConfiguratorConnectionString: 'https://new-configurator.example.com',
        productAnalyticsDataCollectorHost: 'https://new-collector.example.com',
        cubeApiBaseUrl: 'https://new-cube.example.com',
        cubeApiKey: 'new-cube-key',
      },
      {
        productAnalyticsConfiguratorConnectionString: null,
        productAnalyticsDataCollectorHost: null,
        cubeApiBaseUrl: null,
        cubeApiKey: null,
      },
    ])('updates the cache with the provided settings', (updatedSettings) => {
      updateProjectSettingsApolloCache(apolloCache, projectPath, updatedSettings);

      const data = apolloCache.readQuery({
        query: getProductAnalyticsProjectSettings,
        variables: { projectPath },
      });

      expect(data.project.productAnalyticsSettings).toEqual(updatedSettings);
    });
  });
});
