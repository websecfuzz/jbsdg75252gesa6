<script>
import { n__ } from '~/locale';
import { DORA_METRICS } from '~/analytics/shared/constants';
import ComparisonTable from 'ee/analytics/dashboards/dora_projects_comparison/components/comparison_table.vue';

export default {
  name: 'DoraProjectsComparison',
  components: {
    ComparisonTable,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
  computed: {
    filteredProjects() {
      const hasData = (project) =>
        [
          project[DORA_METRICS.DEPLOYMENT_FREQUENCY],
          project[DORA_METRICS.LEAD_TIME_FOR_CHANGES],
          project[DORA_METRICS.TIME_TO_RESTORE_SERVICE],
          project[DORA_METRICS.CHANGE_FAILURE_RATE],
        ].some((value) => value !== null);

      return this.data.projects.filter(hasData);
    },
  },
  mounted() {
    const shownProjectText = n__(
      'Showing %d project.',
      'Showing %d projects.',
      this.filteredProjects.length,
    );
    const excludedProjectText = n__(
      'Excluding %d project with no DORA metrics.',
      'Excluding %d projects with no DORA metrics.',
      this.data.count - this.filteredProjects.length,
    );
    this.$emit('showTooltip', { description: `${shownProjectText} ${excludedProjectText}` });
  },
};
</script>

<template>
  <comparison-table :projects="filteredProjects" />
</template>
