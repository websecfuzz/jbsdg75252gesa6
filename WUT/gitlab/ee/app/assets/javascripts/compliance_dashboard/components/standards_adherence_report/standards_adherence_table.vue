<script>
import { GlAlert, GlDisclosureDropdown } from '@gitlab/ui';
import { s__ } from '~/locale';
import { mapStandardsAdherenceQueryToFilters } from 'ee/compliance_dashboard/utils';
import getProjectsInComplianceStandardsAdherence from 'ee/compliance_dashboard/graphql/compliance_projects_in_standards_adherence.query.graphql';
import { ALLOWED_FILTER_TOKENS, NONE, CHECKS, PROJECTS, STANDARDS } from './constants';
import AdherencesBaseTable from './base_table.vue';
import Filters from './filters.vue';
import GroupAdherences from './group_adherences.vue';

export default {
  name: 'ComplianceStandardsAdherenceTable',
  components: {
    GlAlert,
    GlDisclosureDropdown,
    Filters,
    AdherencesBaseTable,
    GroupAdherences,
  },
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
      hasFilterValueError: false,
      hasRawTextError: false,
      projects: {
        list: [],
      },
      filters: {},
      selected: NONE,
    };
  },
  apollo: {
    projects: {
      skip() {
        return this.projectPath;
      },
      query: getProjectsInComplianceStandardsAdherence,
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      update(data) {
        const nodes = data?.group?.projects.nodes || [];
        return {
          list: nodes,
        };
      },
    },
  },
  computed: {
    projectsForFilter() {
      return this.projectPath ? null : this.projects.list;
    },

    dropdownItems() {
      return [
        {
          text: NONE,
        },
        {
          text: CHECKS,
        },
        ...(!this.projectPath ? [{ text: PROJECTS }] : []),
        {
          text: STANDARDS,
        },
      ];
    },
  },
  methods: {
    onFiltersChanged(filters) {
      this.hasFilterValueError = false;
      this.hasRawTextError = false;

      const availableProjectIDs = this.projects.list.map((item) => item.id);

      filters.forEach((filter) => {
        if (
          filter.type === 'standard' &&
          !ALLOWED_FILTER_TOKENS.standards.includes(filter.value.data)
        ) {
          this.hasFilterValueError = true;
        }
        if (filter.type === 'check' && !ALLOWED_FILTER_TOKENS.checks.includes(filter.value.data)) {
          this.hasFilterValueError = true;
        }
        if (filter.type === 'project' && !availableProjectIDs.includes(filter.value.data)) {
          this.hasFilterValueError = true;
        }
        if (!filter.type) {
          this.hasRawTextError = true;
        }
      });

      if (!this.hasFilterValueError) {
        this.filters = mapStandardsAdherenceQueryToFilters(filters);
      }
    },
    clearFilters() {
      this.filters = {};
    },
    onGroupSelected(selected) {
      this.selected = selected.text;

      if (this.$route.query.before || this.$route.query.after) {
        this.$router.push({
          query: {
            ...this.$route.query,
            before: undefined,
            after: undefined,
          },
        });
      }
    },
  },
  i18n: {
    rawFiltersNotSupported: s__(
      'ComplianceStandardsAdherence|Raw text search is not currently supported. Please use the available filters.',
    ),
    invalidFilterValue: s__(
      'ComplianceStandardsAdherence|Raw filter values is not currently supported. Please use available values.',
    ),
    groupByText: s__('ComplianceStandardsAdherence|Group by'),
    filterByText: s__('ComplianceStandardsAdherence|Filter by'),
  },
  NONE,
  CHECKS,
  PROJECTS,
};
</script>

<template>
  <section>
    <gl-alert v-if="hasFilterValueError" variant="warning" class="gl-mt-3" :dismissible="false">
      {{ $options.i18n.invalidFilterValue }}
    </gl-alert>
    <gl-alert v-if="hasRawTextError" variant="warning" class="gl-mt-3" :dismissible="false">
      {{ $options.i18n.rawFiltersNotSupported }}
    </gl-alert>
    <div class="row-content-block gl-flex gl-border-0 md:gl-flex-row">
      <div class="gl-flex gl-flex-col">
        <label data-testid="dropdown-label" class="gl-leading-normal">
          {{ $options.i18n.groupByText }}
        </label>
        <gl-disclosure-dropdown
          class="gl-mr-6 lg:gl-mb-0"
          :items="dropdownItems"
          :toggle-text="selected"
          @action="onGroupSelected"
        />
      </div>
      <div class="gl-flex gl-grow-2 gl-flex-col">
        <label for="target-branch-input" class="gl-leading-normal">
          {{ $options.i18n.filterByText }}
        </label>
        <filters
          class="gl-mb-2 lg:gl-mb-0"
          :projects="projectsForFilter"
          :group-path="groupPath"
          @submit="onFiltersChanged"
          @clear="clearFilters"
        />
      </div>
    </div>
    <div v-if="selected !== $options.NONE">
      <group-adherences
        :group-path="groupPath"
        :project-path="projectPath"
        :filters="filters"
        :selected="selected"
        :projects="projects.list"
      />
    </div>
    <div v-else>
      <adherences-base-table
        :group-path="groupPath"
        :filters="filters"
        :project-path="projectPath"
      />
    </div>
  </section>
</template>
