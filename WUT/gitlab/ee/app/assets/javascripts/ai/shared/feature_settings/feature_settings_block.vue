<script>
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';

export default {
  name: 'FeatureSettingsBlock',
  components: {
    SettingsBlock,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <div class="gl-mt-5 gl-border-t-1 gl-border-subtle gl-pt-5 gl-border-t-solid">
    <settings-block :id="id" :title="title" :expanded="true">
      <template #description>
        <slot name="description"></slot>
      </template>
      <template #default>
        <slot name="content"></slot>
      </template>
    </settings-block>
  </div>
</template>
