import Vue from 'vue';
import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import App from 'ee/vue_merge_request_widget/components/widget/app.vue';
import MrSecurityWidgetEE from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue';
import MrSecurityWidgetCE from '~/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue';
import MrTestReportWidget from '~/vue_merge_request_widget/widgets/test_report/index.vue';
import StateContainer from '~/vue_merge_request_widget/components/state_container.vue';
import MrMetricsWidget from 'ee/vue_merge_request_widget/widgets/metrics/index.vue';
import MrCodeQualityWidget from '~/vue_merge_request_widget/widgets/code_quality/index.vue';
import MrTerraformWidget from '~/vue_merge_request_widget/widgets/terraform/index.vue';
import MrStatusChecksWidget from 'ee/vue_merge_request_widget/widgets/status_checks/index.vue';
import MrBrowserPerformanceWidget from 'ee/vue_merge_request_widget/widgets/browser_performance/index.vue';
import MrLoadPerformanceWidget from 'ee/vue_merge_request_widget/widgets/load_performance/index.vue';
import MrLicenseComplianceWidget from 'ee/vue_merge_request_widget/widgets/license_compliance/index.vue';
import violationsCountQuery from 'ee/merge_requests/reports/queries/violations_count.query.graphql';

Vue.use(VueApollo);

describe('MR Widget App', () => {
  let wrapper;
  let mock;
  let mockApollo;
  let violationsCountQueryMock;

  const findStateContainer = () => wrapper.findComponent(StateContainer);

  const createComponent = ({ mr = {}, violationsCount = 0, mrReportsTab = false } = {}) => {
    violationsCountQueryMock = jest.fn().mockResolvedValue({
      data: {
        project: { id: 1, mergeRequest: { id: 1, policyViolations: { violationsCount } } },
      },
    });

    mockApollo = createMockApollo([[violationsCountQuery, violationsCountQueryMock]]);

    wrapper = shallowMountExtended(App, {
      apolloProvider: mockApollo,
      propsData: {
        mr: {
          securityConfigurationPath: '/help/user/application_security/_index.md',
          sourceProjectFullPath: 'namespace/project',
          pipeline: {
            path: '/path/to/pipeline',
          },
          ...mr,
        },
      },
      provide: {
        glFeatures: { mrReportsTab },
      },
      stubs: { GlSprintf },
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mockApollo = null;
    mock.restore();
  });

  describe('MRSecurityWidget', () => {
    it('mounts MrSecurityWidgetEE when user has necessary permissions', async () => {
      createComponent({ mr: { canReadVulnerabilities: true } });

      await waitForPromises();

      expect(wrapper.findComponent(MrSecurityWidgetEE).exists()).toBe(true);
    });

    it('mounts MrSecurityWidgetCE when user does not have necessary permissions', async () => {
      createComponent({ mr: { canReadVulnerabilities: false } });

      await waitForPromises();

      expect(wrapper.findComponent(MrSecurityWidgetCE).exists()).toBe(true);
    });
  });

  describe('License Compliance Widget', () => {
    it('is mounted when the report is enabled and endpoint is provided', async () => {
      createComponent({
        mr: {
          enabledReports: { licenseScanning: true },
          licenseCompliance: { license_scanning: { full_report_path: 'full/report/path' } },
        },
      });

      await waitForPromises();

      expect(wrapper.findComponent(MrLicenseComplianceWidget).exists()).toBe(true);
    });

    it('is not mounted when the report is not enabled', async () => {
      createComponent({ mr: { enabledReports: {} } });

      await waitForPromises();

      expect(wrapper.findComponent(MrLicenseComplianceWidget).exists()).toBe(false);
    });
  });

  describe.each`
    widgetName                    | widget                        | endpoint
    ${'testReportWidget'}         | ${MrTestReportWidget}         | ${'testResultsPath'}
    ${'metricsWidget'}            | ${MrMetricsWidget}            | ${'metricsReportsPath'}
    ${'codeQualityWidget'}        | ${MrCodeQualityWidget}        | ${'codequalityReportsPath'}
    ${'terraformPlansWidget'}     | ${MrTerraformWidget}          | ${'terraformReportsPath'}
    ${'statusChecksWidget'}       | ${MrStatusChecksWidget}       | ${'apiStatusChecksPath'}
    ${'browserPerformanceWidget'} | ${MrBrowserPerformanceWidget} | ${'browserPerformance'}
    ${'loadPerformanceWidget'}    | ${MrLoadPerformanceWidget}    | ${'loadPerformance'}
  `('$widgetName', ({ widget, endpoint }) => {
    beforeEach(() => {
      mock.onGet(endpoint).reply(HTTP_STATUS_OK);
    });

    it(`is mounted when ${endpoint} is defined`, async () => {
      createComponent({ mr: { [endpoint]: `path/to/${endpoint}` } });

      await waitForPromises();
      jest.advanceTimersByTime(1);

      expect(wrapper.findComponent(widget).exists()).toBe(true);
    });

    it(`is not mounted when ${endpoint} is not defined`, async () => {
      createComponent();

      await waitForPromises();
      jest.advanceTimersByTime(1);

      expect(wrapper.findComponent(widget).exists()).toBe(false);
    });
  });

  describe('when mrReportsTab is enabled', () => {
    describe('when mr.hasPolicies is false', () => {
      it('does not call GraphQL query', async () => {
        createComponent({ mr: { hasPolicies: false }, mrReportsTab: true });

        await waitForPromises();

        expect(violationsCountQueryMock).not.toHaveBeenCalled();
      });
    });

    describe('when mr.hasPolicies is true', () => {
      describe.each`
        violationsCount | title                    | icon
        ${0}            | ${'0 policy violations'} | ${'success'}
        ${1}            | ${'1 policy violation'}  | ${'failed'}
        ${2}            | ${'2 policy violations'} | ${'failed'}
      `('when violations count is $violationsCount', ({ violationsCount, title, icon }) => {
        beforeEach(async () => {
          createComponent({
            mr: {
              hasPolicies: true,
              iid: 1,
              targetProjectFullPath: 'gitlab-org',
              testResultsPath: '/test-results',
            },
            mrReportsTab: true,
            violationsCount,
          });

          await waitForPromises();
        });

        it(`sets collapsed text as ${title}`, () => {
          expect(findStateContainer().text()).toContain(title);
        });

        it(`sets icon as ${icon}`, () => {
          expect(findStateContainer().props('status')).toBe(icon);
        });
      });
    });
  });
});
