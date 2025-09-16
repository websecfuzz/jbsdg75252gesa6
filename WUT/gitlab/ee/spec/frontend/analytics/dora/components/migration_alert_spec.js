import { GlAlert } from '@gitlab/ui';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import MigrationAlert from 'ee/analytics/dora/components/migration_alert.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('MigrationAlert', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createWrapper = ({ props = {}, shouldShowCallout = true }) => {
    userCalloutDismissSpy = jest.fn();
    wrapper = mountExtended(MigrationAlert, {
      propsData: {
        namespacePath: 'bananza',
        ...props,
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findCalloutDismisser = () => wrapper.findComponent(UserCalloutDismisser);
  const findDashboardsLink = () => wrapper.findByTestId('dashboardsLink');
  const findDoraMetricsLink = () => wrapper.findByTestId('doraMetricsLink');

  describe('when callout is hidden', () => {
    beforeEach(() => {
      createWrapper({ shouldShowCallout: false });
    });

    it('does not render the alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe.each`
    isProject | calloutFeatureName                    | dashboardsLink                              | doraMetricsLink
    ${false}  | ${'dora_dashboard_migration_group'}   | ${'/groups/bananza/-/analytics/dashboards'} | ${'/groups/bananza/-/analytics/dashboards/dora_metrics'}
    ${true}   | ${'dora_dashboard_migration_project'} | ${'/bananza/-/analytics/dashboards'}        | ${'/bananza/-/analytics/dashboards/dora_metrics'}
  `(
    'when isProject=$isProject',
    ({ isProject, calloutFeatureName, dashboardsLink, doraMetricsLink }) => {
      beforeEach(() => {
        createWrapper({ props: { isProject } });
      });

      it('passes the correct feature name to the callout dismisser', () => {
        expect(findCalloutDismisser().props().featureName).toBe(calloutFeatureName);
      });

      it('renders the alert', () => {
        const title = 'Looking for DORA metrics?';
        expect(findAlert().props().title).toBe(title);
        expect(findAlert().text()).toBe(
          `${title} DORA metrics have moved to Analytics dashboards > DORA metrics.`,
        );
      });

      it('emits dismiss when alert is dismissed', () => {
        findAlert().vm.$emit('dismiss');
        expect(userCalloutDismissSpy).toHaveBeenCalled();
      });

      it('generates the dashboard list link for the namespace', () => {
        expect(findDashboardsLink().attributes('href')).toBe(dashboardsLink);
      });

      it('generates the dora metric dashboard link for the namespace', () => {
        expect(findDoraMetricsLink().attributes('href')).toBe(doraMetricsLink);
      });
    },
  );
});
