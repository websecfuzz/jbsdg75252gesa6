<script>
import { GlButton } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_AGENTS_NEW_ROUTE } from './router/constants';
import AiCatalogNavTabs from './components/ai_catalog_nav_tabs.vue';

export default {
  name: 'AiCatalogApp',
  components: {
    AiCatalogNavTabs,
    PageHeading,
    GlButton,
  },
  newAgentRoute: { name: AI_CATALOG_AGENTS_NEW_ROUTE },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|AI Catalog')">
      <template #actions>
        <gl-button :to="$options.newAgentRoute" variant="confirm">
          {{ s__('AICatalog|New agent') }}
        </gl-button>
      </template>
    </page-heading>
    <ai-catalog-nav-tabs />
    <router-view />
  </div>
</template>
