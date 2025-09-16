import { shallowMount } from '@vue/test-utils';
import { GlAlert, GlToggle } from '@gitlab/ui';
import ComplianceStandardsAdherenceReport from 'ee/compliance_dashboard/components/standards_adherence_report/report.vue';
import ComplianceStandardsAdherenceTable from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_table.vue';
import ComplianceStandardsAdherenceTableV2 from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_table_v2.vue';
import { mockTracking } from 'helpers/tracking_helper';

describe('ComplianceStandardsAdherenceReport component', () => {
  let wrapper;
  let trackingSpy;

  const groupPath = 'example-group';
  const projectPath = 'example-project';

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findToggle = () => wrapper.findComponent(GlToggle);
  const findAdherencesTable = () => wrapper.findComponent(ComplianceStandardsAdherenceTable);
  const findNewAdherencesTable = () => wrapper.findComponent(ComplianceStandardsAdherenceTableV2);

  const createComponent = (customProvide = {}) => {
    wrapper = shallowMount(ComplianceStandardsAdherenceReport, {
      propsData: {
        groupPath,
        projectPath,
      },
      provide: { adherenceV2Enabled: false, activeComplianceFrameworks: false, ...customProvide },
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the alert message', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('renders the standards adherence table component', () => {
      expect(findAdherencesTable().exists()).toBe(true);
    });

    it('passes props to the standards adherence table component', () => {
      expect(findAdherencesTable().props()).toMatchObject({ groupPath, projectPath });
    });
  });

  describe('tracking', () => {
    describe('no active frameworks', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
        createComponent();
      });

      it('tracks without property', () => {
        expect(trackingSpy).toHaveBeenCalledTimes(1);
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'user_perform_visit', {});
      });
    });

    describe('with active frameworks', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
        createComponent({ activeComplianceFrameworks: true });
      });

      it('tracks when mounted', () => {
        expect(trackingSpy).toHaveBeenCalledTimes(1);
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'user_perform_visit', {
          with_active_compliance_frameworks: 'true',
        });
      });
    });
  });
  describe('with v2 Report active', () => {
    beforeEach(() => {
      trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
      createComponent({ adherenceV2Enabled: true });
    });

    it('shows alert banner', () => {
      expect(findAlert().exists()).toBe(true);
    });

    it('shows the new report', () => {
      expect(findAdherencesTable().exists()).toBe(false);
      expect(findNewAdherencesTable().exists()).toBe(true);
    });

    it('toggles report to the old table, with tracking', async () => {
      const toggle = findToggle();

      await toggle.vm.$emit('change', false);
      await toggle.trigger('click');

      expect(trackingSpy).toHaveBeenCalledTimes(2);
      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        'toggle_standards_adherence_report_version',
        {},
      );

      expect(findAdherencesTable().exists()).toBe(true);
      expect(findNewAdherencesTable().exists()).toBe(false);
    });
  });
});
