<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ConfigureLabels from './security_labels/configure_labels.vue';

export default {
  components: {
    GlTabs,
    GlTab,
    PageHeading,
    ConfigureLabels,
  },
};
</script>
<template>
  <div>
    <page-heading :heading="s__('SecurityConfiguration|Security configuration')" />
    <gl-tabs>
      <gl-tab :title="s__('SecurityLabels|Security labels')">
        <p class="gl-my-5">
          {{
            s__(
              'SecurityLabels|Use security labels to categorize projects by business context, security needs, and more. Categories are shared across your groups, enabling consistent and scalable classification of assets. These labels can help prioritize security efforts, filter dashboards, and apply consistent governance across projects.',
            )
          }}
        </p>
        <configure-labels />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
