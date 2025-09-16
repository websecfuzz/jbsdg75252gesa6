<script>
import { GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import { AI_CATALOG_AGENTS_ROUTE } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';
import { TYPENAME_AI_CATALOG_ITEM } from '../constants';

export default {
  name: 'AiCatalogAgentsShow',
  components: {
    AiCatalogAgentForm,
    GlModal,
    PageHeading,
  },
  apollo: {
    aiCatalogItem: {
      query: aiCatalogAgentQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
        };
      },
      result(res) {
        this.onAgentQueryResult(res);
      },
    },
  },
  data() {
    return {
      aiCatalogItem: null,
      isLoading: false,
      updatedValues: {
        name: '',
        description: '',
        systemPrompt: '',
        userPrompt: '',
      },
    };
  },
  computed: {
    agentName() {
      return this.aiCatalogItem?.name || '';
    },
    pageTitle() {
      return `${s__('AICatalog|Edit agent')}: ${this.agentName}`;
    },
  },
  methods: {
    onAgentQueryResult({ data }) {
      if (!data || !data.aiCatalogItem) {
        const queryError = new Error(
          `Agent not found: Failed to query agent with ID ${this.$route.params.id}`,
        );
        Sentry.captureException(queryError);
        this.$router.push({ name: AI_CATALOG_AGENTS_ROUTE });
      }
    },
    handleSubmit(formValues) {
      this.isLoading = true;
      // TODO: Handle submission, dummy cody here. Replace with real implementation
      setTimeout(() => {
        this.updatedValues = formValues;
        this.$refs.modal.show();
        this.isLoading = false;
      }, 1000);
    },
  },
};
</script>

<template>
  <div v-if="aiCatalogItem">
    <page-heading :heading="pageTitle" />
    <p>
      {{ s__('AICatalog|Modify the agent settings and configuration.') }}
    </p>
    <ai-catalog-agent-form
      v-if="aiCatalogItem"
      mode="edit"
      :project-id="aiCatalogItem.project.id"
      :name="aiCatalogItem.name"
      :description="aiCatalogItem.description"
      :system-prompt="aiCatalogItem.systemPrompt"
      :user-prompt="aiCatalogItem.userPrompt"
      :is-loading="isLoading"
      @submit="handleSubmit"
    />
    <gl-modal ref="modal" modal-id="TEMPORARY-MODAL">
      <pre>{{ JSON.stringify(updatedValues) }}</pre>
    </gl-modal>
  </div>
</template>
