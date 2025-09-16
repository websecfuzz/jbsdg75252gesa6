<script>
import { GlSprintf, GlAlert, GlLink, GlToggle } from '@gitlab/ui';
import Tracking from '~/tracking';
import {
  FEEDBACK_ISSUE_URL,
  STANDARDS_ADHERENCE_DOCS_URL,
} from 'ee/compliance_dashboard/constants';
import { s__ } from '~/locale';
import ComplianceStandardsAdherenceTable from './standards_adherence_table.vue';
import ComplianceStandardsAdherenceTableV2 from './standards_adherence_table_v2.vue';

export default {
  name: 'ComplianceStandardsAdherenceReport',
  components: {
    ComplianceStandardsAdherenceTable,
    ComplianceStandardsAdherenceTableV2,
    GlToggle,
    GlAlert,
    GlLink,
    GlSprintf,
  },
  mixins: [Tracking.mixin()],
  inject: ['activeComplianceFrameworks', 'adherenceV2Enabled'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      showBanner: this.adherenceV2Enabled,
      showNewReport: this.adherenceV2Enabled,
    };
  },
  mounted() {
    const additionalProperties = this.activeComplianceFrameworks
      ? {
          with_active_compliance_frameworks: 'true',
        }
      : {};
    this.track('user_perform_visit', additionalProperties);
  },
  methods: {
    updateReportVersion(value) {
      this.track('toggle_standards_adherence_report_version');
      this.$emit('changed', 'report_version', {
        showNewReport: value,
      });
      this.showNewReport = !this.showNewReport;
    },
  },
  i18n: {
    feedbackTitle: s__(
      'AdherenceReport|We are replacing the standards adherence report with the compliance status report, which includes new features to enhance your compliance workflow.',
    ),
    learnMoreDocsText: s__(
      'AdherenceReport|Learn more about the changes in our %{linkStart}documentation%{linkEnd}.',
    ),
    feedbackText: s__(
      'AdherenceReport|Have questions or thoughts on the new improvements we made? %{linkStart}Please provide feedback on your experience%{linkEnd}.',
    ),
    toggleLabel: s__('AdherenceReport|Show old report'),
  },
  FEEDBACK_ISSUE_URL,
  STANDARDS_ADHERENCE_DOCS_URL,
};
</script>

<template>
  <div>
    <gl-alert v-if="showBanner" variant="info" dismissible @dismiss="showBanner = false">
      <div>
        {{ $options.i18n.feedbackTitle }}
        <gl-sprintf :message="$options.i18n.learnMoreDocsText">
          <template #link="{ content }">
            <gl-link :href="$options.STANDARDS_ADHERENCE_DOCS_URL" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
        <gl-sprintf :message="$options.i18n.feedbackText">
          <template #link="{ content }">
            <gl-link :href="$options.FEEDBACK_ISSUE_URL" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </div>
      <div class="gl-mt-4 gl-flex gl-items-center">
        <span class="gl-mr-3">{{ $options.i18n.toggleText }}</span>
        <gl-toggle
          :value="!showNewReport"
          :label="$options.i18n.toggleLabel"
          label-position="left"
          @change="updateReportVersion"
        />
      </div>
    </gl-alert>
    <compliance-standards-adherence-table-v2
      v-if="showNewReport"
      :group-path="groupPath"
      :project-path="projectPath"
    />
    <compliance-standards-adherence-table
      v-else
      :group-path="groupPath"
      :project-path="projectPath"
    />
  </div>
</template>
