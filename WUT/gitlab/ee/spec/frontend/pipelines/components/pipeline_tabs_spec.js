import { GlTab } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import Api from '~/api';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import BasePipelineTabs from '~/ci/pipeline_details/tabs/pipeline_tabs.vue';
import PipelineTabs from 'ee/ci/pipeline_details/tabs/pipeline_tabs.vue';
import CodequalityReportApp from 'ee/codequality_report/codequality_report.vue';
import { SERVICE_PING_PIPELINE_SECURITY_VISIT } from '~/tracking/constants';

jest.mock('~/api.js');

describe('The Pipeline Tabs', () => {
  let wrapper;

  const findCodeQualityTab = () => wrapper.findByTestId('code-quality-tab');
  const findFailedJobsTab = () => wrapper.findByTestId('failed-jobs-tab');
  const findJobsTab = () => wrapper.findByTestId('jobs-tab');
  const findLicenseTab = () => wrapper.findByTestId('license-tab');
  const findPipelineTab = () => wrapper.findByTestId('pipeline-tab');
  const findSecurityTab = () => wrapper.findByTestId('security-tab');
  const findTestsTab = () => wrapper.findByTestId('tests-tab');
  const findLicenseCounter = () => wrapper.findByTestId('license-counter');
  const getLicenseCount = () => findLicenseCounter().text();
  const getCodequalityCount = () => wrapper.findByTestId('codequality-counter');
  const findCodeQualityRouterView = () => wrapper.findComponent({ ref: 'router-view-codequality' });
  const findLicensesRouterView = () => wrapper.findComponent({ ref: 'router-view-licenses' });

  const defaultProvide = {
    canGenerateCodequalityReports: false,
    canManageLicenses: true,
    codequalityReportDownloadPath: '',
    defaultTabValue: '',
    exposeSecurityDashboard: false,
    exposeLicenseScanningData: false,
    failedJobsCount: 1,
    isFullCodequalityReportAvailable: true,
    licenseManagementApiUrl: '/path/to/license_management_api_url',
    licensesApiPath: '/path/to/licenses_api',
    securityPoliciesPath: '/path/to/-/security/policies',
    licenseScanCount: 11,
    pipelineIid: '100',
    totalJobCount: 10,
    testsCount: 123,
    manualVariablesCount: 0,
  };

  const $router = {
    push: jest.fn(),
  };

  const createComponent = ({ propsData = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(PipelineTabs, {
        propsData,
        provide: {
          ...defaultProvide,
          ...provide,
        },
        stubs: {
          BasePipelineTabs,
          RouterView: true,
          ...stubs,
        },
        mocks: {
          $router,
        },
      }),
    );
  };

  it('lazy loads all tabs', () => {
    createComponent({
      stubs: {
        GlTab,
      },
      propsData: {
        sbomReportsErrors: [],
      },
    });
    const tabs = wrapper.findAllComponents(GlTab);

    tabs.wrappers.forEach((tab) => {
      expect(tab.attributes('lazy')).toBe('true');
    });
  });

  describe('CE Tabs', () => {
    it.each`
      tabName          | tabComponent
      ${'Pipeline'}    | ${findPipelineTab}
      ${'Jobs'}        | ${findJobsTab}
      ${'Failed Jobs'} | ${findFailedJobsTab}
      ${'Tests'}       | ${findTestsTab}
    `('shows $tabName tab with its associated component', ({ tabComponent }) => {
      createComponent({
        propsData: {
          sbomReportsErrors: [],
        },
      });

      expect(tabComponent().exists()).toBe(true);
    });

    describe('with no failed jobs', () => {
      beforeEach(() => {
        createComponent({
          provide: { failedJobsCount: 0 },
          propsData: {
            sbomReportsErrors: [],
          },
        });
      });

      it('hides the failed jobs tab', () => {
        expect(findFailedJobsTab().exists()).toBe(false);
      });
    });
  });

  describe('EE Tabs', () => {
    describe('visibility', () => {
      it.each`
        tabName       | tabComponent       | provideKey                     | isVisible | text
        ${'Security'} | ${findSecurityTab} | ${'exposeSecurityDashboard'}   | ${true}   | ${'shows'}
        ${'Security'} | ${findSecurityTab} | ${'exposeSecurityDashboard'}   | ${false}  | ${'hides'}
        ${'License'}  | ${findLicenseTab}  | ${'exposeLicenseScanningData'} | ${true}   | ${'shows'}
        ${'License'}  | ${findLicenseTab}  | ${'exposeLicenseScanningData'} | ${false}  | ${'hides'}
      `(
        '$text $tabName tab when $provideKey is $provideKey',
        ({ tabComponent, provideKey, isVisible }) => {
          createComponent({
            provide: { [provideKey]: isVisible },
            propsData: {
              sbomReportsErrors: [],
            },
          });
          expect(tabComponent().exists()).toBe(isVisible);
        },
      );
    });

    it.each`
      canGenerate | isVisible | codequalityReportDownloadPath | isReportAvailable | text
      ${true}     | ${true}   | ${''}                         | ${true}           | ${'shows'}
      ${false}    | ${false}  | ${''}                         | ${true}           | ${'hides'}
      ${false}    | ${true}   | ${'/path'}                    | ${true}           | ${'shows'}
      ${true}     | ${true}   | ${'/path'}                    | ${true}           | ${'shows'}
      ${true}     | ${false}  | ${'/path'}                    | ${false}          | ${'hides'}
    `(
      '$text Code Quality tab when canGenerateCodequalityReports is $canGenerate and codequalityReportDownloadPath is $codequalityReportDownloadPath',
      ({ canGenerate, isReportAvailable, isVisible, codequalityReportDownloadPath }) => {
        createComponent({
          provide: {
            isFullCodequalityReportAvailable: isReportAvailable,
            canGenerateCodequalityReports: canGenerate,
            codequalityReportDownloadPath,
          },
          propsData: {
            sbomReportsErrors: [],
          },
        });
        expect(findCodeQualityTab().exists()).toBe(isVisible);
      },
    );
  });

  describe('codequality badge count', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          isFullCodequalityReportAvailable: true,
          canGenerateCodequalityReports: true,
          codequalityReportDownloadPath: '/dsda',
        },
        stubs: { GlTab, CodequalityReportApp },
        propsData: {
          sbomReportsErrors: [],
        },
      });
    });

    it('updates the codequality badge after a new count has been emitted', async () => {
      const newLicenseCount = 100;
      expect(getCodequalityCount().exists()).toBe(false);

      findCodeQualityRouterView().vm.$emit('updateBadgeCount', newLicenseCount);
      await nextTick();

      expect(getCodequalityCount().text()).toBe(`${newLicenseCount}`);
    });

    it('shows the correct codequality badge when the count is 0', async () => {
      const newLicenseCount = 0;
      findCodeQualityRouterView().vm.$emit('updateBadgeCount', newLicenseCount);
      await nextTick();

      expect(getCodequalityCount().text()).toBe(`${newLicenseCount}`);
    });
  });

  describe('security', () => {
    beforeEach(() => {
      createComponent({
        provide: { exposeSecurityDashboard: true },
        propsData: {
          sbomReportsErrors: [],
        },
      });
    });

    it('tracks "users_visiting_pipeline_security" metric when tab is selected', () => {
      findSecurityTab().vm.$emit('click');

      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledWith(SERVICE_PING_PIPELINE_SECURITY_VISIT);
    });

    it("doesn't track the metric when other tab is selected", () => {
      findJobsTab().vm.$emit('click');
      findTestsTab().vm.$emit('click');

      expect(Api.trackRedisHllUserEvent).not.toHaveBeenCalled();
    });
  });

  describe('license compliance', () => {
    beforeEach(() => {
      createComponent({
        provide: { exposeLicenseScanningData: true },
        stubs: { GlTab },
        propsData: {
          sbomReportsErrors: [],
        },
      });
    });

    it('passes down all props to the license app', () => {
      expect(findLicensesRouterView().attributes()).toMatchObject({
        'api-url': defaultProvide.licenseManagementApiUrl,
        'licenses-api-path': defaultProvide.licensesApiPath,
        'security-policies-path': defaultProvide.securityPoliciesPath,
        'can-manage-licenses': defaultProvide.canManageLicenses.toString(),
        'always-open': 'true',
      });
    });

    it('sets the initial count and updates the license count badge after a new count has been emitted', async () => {
      const newLicenseCount = 100;

      expect(getLicenseCount()).toBe('11');

      findLicensesRouterView().vm.$emit('updateBadgeCount', newLicenseCount);
      await nextTick();

      expect(getLicenseCount()).toBe(`${newLicenseCount}`);
    });

    describe('when the count is initially undefined', () => {
      beforeEach(() => {
        createComponent({
          provide: { exposeLicenseScanningData: true, licenseScanCount: undefined },
          stubs: { GlTab },
          propsData: {
            sbomReportsErrors: [],
          },
        });
      });

      it('does not show the count on initial page load', () => {
        expect(findLicenseCounter().exists()).toBe(false);
      });

      it('shows count after tab content loads', async () => {
        const newLicenseCount = 100;

        expect(findLicenseCounter().exists()).toBe(false);

        findLicensesRouterView().vm.$emit('updateBadgeCount', newLicenseCount);
        await nextTick();

        expect(findLicenseCounter().exists()).toBe(true);
        expect(getLicenseCount()).toBe(`${newLicenseCount}`);
      });
    });
  });
});
