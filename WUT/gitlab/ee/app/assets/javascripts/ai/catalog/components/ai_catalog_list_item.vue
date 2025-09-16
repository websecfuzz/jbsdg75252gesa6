<script>
import {
  GlAvatar,
  GlBadge,
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlIcon,
  GlMarkdown,
  GlTooltipDirective,
} from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__ } from '~/locale';
import { AI_CATALOG_AGENTS_SHOW_ROUTE, AI_CATALOG_AGENTS_RUN_ROUTE } from '../router/constants';
import { ENUM_TO_NAME_MAP } from '../constants';

export default {
  name: 'AiCatalogListItem',
  components: {
    GlAvatar,
    GlBadge,
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlIcon,
    GlMarkdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  computed: {
    items() {
      const formattedId = getIdFromGraphQLId(this.item.id);
      return [
        {
          text: s__('AICatalog|Run'),
          to: this.$router.resolve({
            name: AI_CATALOG_AGENTS_RUN_ROUTE,
            params: { id: formattedId },
          }).route.path,
          icon: 'rocket-launch',
        },
        {
          text: s__('AICatalog|Edit'),
          to: this.$router.resolve({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: formattedId },
          }).route.path,
          icon: 'pencil',
        },
      ];
    },
  },
  ENUM_TO_NAME_MAP,
};
</script>

<template>
  <li
    data-testid="ai-catalog-list-item"
    class="gl-flex gl-items-center gl-justify-between gl-border-b-1 gl-border-default gl-py-3 gl-text-subtle gl-border-b-solid"
  >
    <div class="gl-flex gl-items-center">
      <gl-avatar
        :alt="`${item.name} avatar`"
        :entity-name="item.name"
        :size="48"
        class="gl-mr-4 gl-self-start"
      />
      <div class="gl-flex gl-grow gl-flex-col gl-gap-1">
        <div class="gl-mb-1 gl-flex gl-flex-wrap gl-items-center gl-gap-2">
          {{ item.name }}
          <gl-badge variant="neutral" class="gl-self-center">
            {{ $options.ENUM_TO_NAME_MAP[item.itemType] }}
          </gl-badge>
        </div>

        <div v-if="item.description" class="gl-line-clamp-2 gl-break-words gl-text-default">
          <gl-markdown compact class="gl-text-sm">{{ item.description }}</gl-markdown>
        </div>
      </div>
    </div>
    <gl-disclosure-dropdown
      :toggle-text="__('More actions')"
      category="tertiary"
      icon="ellipsis_v"
      no-caret
      text-sr-only
    >
      <gl-disclosure-dropdown-group>
        <gl-disclosure-dropdown-item
          v-for="(listItem, index) in items"
          :key="index"
          :item="listItem"
          :to="listItem.to"
        >
          <template #list-item>
            <span>
              <gl-icon :name="listItem.icon" class="gl-mr-2" variant="subtle" aria-hidden="true" />
              {{ listItem.text }}
            </span>
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
      <gl-disclosure-dropdown-group bordered>
        <gl-disclosure-dropdown-item variant="danger">
          <template #list-item>
            <span>
              <gl-icon name="remove" class="gl-mr-2" variant="current" aria-hidden="true" />
              <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
              {{ __('Delete') }} (Coming soon)
            </span>
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>
  </li>
</template>
