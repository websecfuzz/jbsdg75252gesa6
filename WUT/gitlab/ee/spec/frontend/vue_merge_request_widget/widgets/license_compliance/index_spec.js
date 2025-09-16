import MockAdapter from 'axios-mock-adapter';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import api from '~/api';
import axios from '~/lib/utils/axios_utils';
import ActionButtons from '~/vue_merge_request_widget/components/widget/action_buttons.vue';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';

import licenseComplianceExtension from 'ee/vue_merge_request_widget/widgets/license_compliance/index.vue';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import {
  licenseComplianceNewLicenses,
  licenseComplianceSuccessExpanded,
  licenseComplianceRemovedLicenses,
  licenseComplianceNewAndRemovedLicenses,
  licenseComplianceNewDeniedLicenses,
  licenseComplianceNewDeniedLicensesAndExisting,
  licenseComplianceNewAndRemovedLicensesApprovalRequired,
  licenseComplianceNewDeniedLicensesAndExistingApprovalRequired,
  licenseComplianceEmpty,
  licenseComplianceEmptyExistingLicense,
  licenseComplianceExistingAndNewLicenses,
} from './mock_data';

describe('License Compliance extension', () => {
  let wrapper;
  let mock;

  const licenseComparisonPath =
    '/group-name/project-name/-/merge_requests/78/license_scanning_reports';
  const licenseComparisonPathCollapsed =
    '/group-name/project-name/-/merge_requests/78/license_scanning_reports_collapsed';
  const fullReportPath = '/group-name/project-name/-/merge_requests/78/full_report';
  const settingsPath = '/group-name/project-name/-/licenses#licenses';
  const apiApprovalsPath = '/group-name/project-name/-/licenses#policies';

  const mockApi = (endpoint, statusCode, data) => {
    mock.onGet(endpoint).reply(statusCode, data, {});
  };

  const findWidget = () => wrapper.findComponent(Widget);
  const findToggleCollapsedButton = () => wrapper.findByTestId('toggle-button');
  const findAllExtensionListItems = () => wrapper.findAllByTestId('extension-list-item');
  const findActionButtons = () => wrapper.findComponent(ActionButtons);
  const findByHrefAttribute = (href) => wrapper.find(`[href="${href}"]`);
  const findFullReportLink = () => findByHrefAttribute(fullReportPath);
  const findSummary = () => wrapper.findByTestId('widget-extension-top-level-summary');

  const createComponent = (licenseComplianceProps = {}) => {
    wrapper = mountExtended(licenseComplianceExtension, {
      propsData: {
        mr: {
          licenseCompliance: {
            license_scanning_comparison_path: licenseComparisonPath,
            license_scanning_comparison_collapsed_path: licenseComparisonPathCollapsed,
            api_approvals_path: apiApprovalsPath,
            license_scanning: {
              settings_path: settingsPath,
              full_report_path: fullReportPath,
            },
            ...licenseComplianceProps,
          },
        },
      },
    });
  };

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  it('emits loaded event', async () => {
    mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

    createComponent();

    await waitForPromises();

    expect(wrapper.emitted('loaded')[0]).toContain(4);
  });

  describe('summary', () => {
    it('displays loading text', () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      expect(findSummary().text()).toBe('License Compliance test metrics results are being parsed');
    });

    it('displays failed loading text', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_INTERNAL_SERVER_ERROR);

      createComponent();

      await waitForPromises();
      expect(findSummary().text()).toBe('License Compliance failed loading results');
    });

    it.each`
      scenario                                                            | response                                                         | isExpandable | message
      ${'licenseComplianceEmpty'}                                         | ${licenseComplianceEmpty}                                        | ${false}     | ${'License Compliance detected no licenses for the source branch only'}
      ${'licenseComplianceEmptyExistingLicense'}                          | ${licenseComplianceEmptyExistingLicense}                         | ${false}     | ${'License Compliance detected no new licenses'}
      ${'licenseComplianceNewLicenses'}                                   | ${licenseComplianceNewLicenses}                                  | ${true}      | ${'License Compliance detected 4 licenses for the source branch only'}
      ${'licenseComplianceRemovedLicenses'}                               | ${licenseComplianceRemovedLicenses}                              | ${false}     | ${'License Compliance detected no licenses for the source branch only'}
      ${'licenseComplianceNewAndRemovedLicenses'}                         | ${licenseComplianceNewAndRemovedLicenses}                        | ${true}      | ${'License Compliance detected 2 licenses for the source branch only'}
      ${'licenseComplianceNewAndRemovedLicensesApprovalRequired'}         | ${licenseComplianceNewAndRemovedLicensesApprovalRequired}        | ${true}      | ${'License Compliance detected 4 licenses and policy violations for the source branch only; approval required'}
      ${'licenseComplianceNewDeniedLicenses'}                             | ${licenseComplianceNewDeniedLicenses}                            | ${true}      | ${'License Compliance detected 4 licenses and policy violations for the source branch only'}
      ${'licenseComplianceNewDeniedLicensesAndExisting'}                  | ${licenseComplianceNewDeniedLicensesAndExisting}                 | ${true}      | ${'License Compliance detected 4 new licenses and policy violations'}
      ${'licenseComplianceNewDeniedLicensesAndExistingApprovalRequired '} | ${licenseComplianceNewDeniedLicensesAndExistingApprovalRequired} | ${true}      | ${'License Compliance detected 4 new licenses and policy violations; approval required'}
      ${'licenseComplianceExistingAndNewLicenses'}                        | ${licenseComplianceExistingAndNewLicenses}                       | ${true}      | ${'License Compliance detected 6 new licenses'}
    `(
      'the $scenario scenario expects the message to be "$message"',
      async ({ response, message, isExpandable }) => {
        mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, response);
        createComponent();

        await waitForPromises();

        expect(findSummary().text()).toBe(message);
        expect(findToggleCollapsedButton().exists()).toBe(isExpandable);
      },
    );

    it('displays the help popover', () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      expect(findWidget().props('helpPopover')).toEqual({
        content: {
          learnMorePath:
            '/help/user/compliance/license_approval_policies#criteria-to-compare-licenses-detected-in-the-merge-request-branch-to-licenses-in-the-default-branch',
          text: 'Detects known vulnerabilities in your software dependencies.',
        },
        options: {
          title: 'License scan results',
        },
      });
    });
  });

  describe('actions buttons', () => {
    it('displays manage licenses and full report links', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      await waitForPromises();

      expect(findFullReportLink().exists()).toBe(true);
      expect(findFullReportLink().text()).toBe('Full report');

      expect(findActionButtons().exists()).toBe(true);
    });

    it('should specify trackFullReportClicked property on full report action', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      await waitForPromises();

      expect(findWidget().props('actionButtons')[0]).toMatchObject({
        trackFullReportClicked: true,
      });
    });

    it('hides the manage licenses button when URL is not available', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent({
        license_scanning: {
          settings_path: '',
          full_report_path: fullReportPath,
        },
      });

      await waitForPromises();

      expect(findFullReportLink().exists()).toBe(true);
      expect(findFullReportLink().text()).toBe('Full report');

      expect(findActionButtons().exists()).toBe(true);
    });
  });

  describe('expanded data', () => {
    describe('with new licenses', () => {
      beforeEach(async () => {
        mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);
        mockApi(licenseComparisonPath, HTTP_STATUS_OK, licenseComplianceSuccessExpanded);

        createComponent();

        await waitForPromises();

        findToggleCollapsedButton().trigger('click');

        await waitForPromises();
      });

      it('displays denied licenses', () => {
        expect(findAllExtensionListItems().at(0).element).toMatchSnapshot();
      });

      it('displays uncategorized licenses', () => {
        expect(findAllExtensionListItems().at(1).element).toMatchSnapshot();
      });

      it('displays allowed licenses', () => {
        expect(findAllExtensionListItems().at(2).element).toMatchSnapshot();
      });
    });
  });
});
