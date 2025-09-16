import InstrumentationInstructions from 'ee/product_analytics/onboarding/components/instrumentation_instructions.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockTracking } from 'helpers/tracking_helper';
import { IMPORT_NPM_PACKAGE, INSTALL_NPM_PACKAGE } from 'ee/product_analytics/onboarding/constants';
import {
  TEST_COLLECTOR_HOST,
  TEST_TRACKING_KEY,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';

describe('ProductAnalyticsInstrumentationInstructions', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let trackingSpy;

  const findNpmInstructions = () => wrapper.findByTestId('npm-instrumentation-instructions');
  const findHtmlInstructions = () => wrapper.findByTestId('html-instrumentation-instructions');
  const findFurtherBrowserSDKInfo = () => wrapper.findByTestId('further-browser-sdk-info');
  const findSummaryText = () => wrapper.findByTestId('summary-text');

  const createWrapper = (mountFn = shallowMountExtended) => {
    trackingSpy = mockTracking(undefined, window.document, jest.spyOn);
    wrapper = mountFn(InstrumentationInstructions, {
      propsData: {
        trackingKey: TEST_TRACKING_KEY,
        dashboardsPath: '/foo/bar/dashboards',
      },
      provide: {
        collectorHost: TEST_COLLECTOR_HOST,
      },
    });
  };

  describe('when mounted', () => {
    beforeEach(() => createWrapper());

    it('renders the expected instructions', () => {
      createWrapper(mountExtended);

      const expectedAppIdFragment = `appId: '${TEST_TRACKING_KEY}'`;
      const expectedHostFragment = `host: '${TEST_COLLECTOR_HOST}'`;

      const npmInstructions = findNpmInstructions().text();
      expect(npmInstructions).toContain(INSTALL_NPM_PACKAGE);
      expect(npmInstructions).toContain(IMPORT_NPM_PACKAGE);
      expect(npmInstructions).toContain(expectedAppIdFragment);
      expect(npmInstructions).toContain(expectedHostFragment);

      const htmlInstructions = findHtmlInstructions().text();
      expect(htmlInstructions).toContain(expectedAppIdFragment);
      expect(htmlInstructions).toContain(expectedHostFragment);
    });

    it('tracks that instrumentation instructions has been viewed', () => {
      createWrapper();

      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        'user_viewed_instrumentation_directions',
        expect.any(Object),
      );
    });

    describe('static text', () => {
      it('renders the further browser SDK info text', () => {
        expect(findFurtherBrowserSDKInfo().attributes('message')).toBe(
          'For more information, see the %{linkStart}docs%{linkEnd}.',
        );
      });

      it('renders the summary text', () => {
        expect(findSummaryText().attributes('message')).toBe(
          'After your application has been instrumented and data is being collected, you can visualize and monitor behaviors in your %{linkStart}analytics dashboards%{linkEnd}.',
        );
      });
    });
  });
});
