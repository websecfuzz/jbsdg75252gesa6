<script>
import { GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { createAlert } from '~/alert';
import createAiCatalogAgent from '../graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

export default {
  name: 'AiCatalogAgentsNew',
  components: {
    AiCatalogAgentForm,
    GlModal,
    PageHeading,
  },
  data() {
    return { newAgent: null, isSubmitting: false };
  },
  methods: {
    async handleSubmit(formValues) {
      this.isSubmitting = true;
      // TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/555081
      const input = {
        ...formValues,
        public: true,
      };
      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogAgent,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors } = data.aiCatalogAgentCreate;
          if (errors.length > 0) {
            createAlert({
              message: errors[0],
            });
            this.isSubmitting = false;
            return;
          }

          this.newAgent = data.aiCatalogAgentCreate.item;
          this.$refs.modal.show();
          this.isSubmitting = false;
        }
      } catch (error) {
        createAlert({
          message: s__('AICatalog|The agent could not be added. Please try again.'),
          error,
          captureError: true,
        });
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|Create new agent')" />

    <ai-catalog-agent-form mode="create" :is-loading="isSubmitting" @submit="handleSubmit" />

    <gl-modal ref="modal" modal-id="TEMPORARY-MODAL">
      <h2 class="gl-heading-2">{{ __('Success') }}</h2>
      <pre>{{ JSON.stringify(newAgent) }}</pre>
    </gl-modal>
  </div>
</template>
