<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/ai/catalog/constants';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import AiCatalogAgentRunForm from '../components/ai_catalog_agent_run_form.vue';

export default {
  name: 'AiCatalogAgentsRun',
  components: {
    GlLoadingIcon,
    PageHeading,
    AiCatalogAgentRunForm,
  },
  data() {
    return {
      aiCatalogItem: {},
      isSubmitting: false,
    };
  },
  apollo: {
    aiCatalogItem: {
      query: aiCatalogAgentQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
        };
      },
      update(data) {
        return data?.aiCatalogItem || {};
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogItem.loading;
    },
    pageTitle() {
      return `${s__('AICatalog|Run agent')}: ${this.aiCatalogItem.name}`;
    },
    defaultUserPrompt() {
      return this.aiCatalogItem?.userPrompt || '';
    },
  },
  methods: {
    async onSubmit({ userPrompt }) {
      this.isSubmitting = true;

      try {
        this.$toast.show(userPrompt);
      } catch (error) {
        this.$toast.show(s__('AICatalog|Failed to run agent.'));
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <div v-if="isLoading" class="gl-flex gl-h-full gl-items-center gl-justify-center">
      <gl-loading-icon size="lg" />
    </div>
    <template v-else>
      <page-heading :heading="pageTitle" />

      <ai-catalog-agent-run-form
        :is-submitting="isSubmitting"
        :default-user-prompt="defaultUserPrompt"
        @submit="onSubmit"
      />
    </template>
  </div>
</template>
