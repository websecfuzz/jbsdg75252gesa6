<script>
import { GlCollapsibleListbox, GlTabs } from '@gitlab/ui';
import { __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';
import PermissionsTable from './secrets_manager_permissions_table.vue';

export default {
  name: 'SecretsManagerPermissionsSettings',
  components: {
    CrudComponent,
    GlCollapsibleListbox,
    GlTabs,
    PermissionsTable,
  },
  props: {
    canManageSecretsManager: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      selectedAction: null,
      secretsPermissions: [],
    };
  },
  CREATE_OPTIONS: [
    {
      text: __('Users'),
      value: PERMISSION_CATEGORY_USER,
    },
    {
      text: __('Groups'),
      value: PERMISSION_CATEGORY_GROUP,
    },
    {
      text: __('Roles'),
      value: PERMISSION_CATEGORY_ROLE,
    },
  ],
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
};
</script>

<template>
  <crud-component :title="s__('Secrets|Secret manager user permissions')" class="gl-mt-5">
    <template #actions>
      <gl-collapsible-listbox
        v-if="canManageSecretsManager"
        v-model="selectedAction"
        :items="$options.CREATE_OPTIONS"
        :toggle-text="__('Add')"
        data-testid="form-selector"
        size="small"
      />
    </template>
    <template #default>
      <gl-tabs>
        <permissions-table
          :items="secretsPermissions"
          :permission-category="$options.PERMISSION_CATEGORY_USER"
        />
        <permissions-table
          :items="secretsPermissions"
          :permission-category="$options.PERMISSION_CATEGORY_GROUP"
        />
        <permissions-table
          :items="secretsPermissions"
          :permission-category="$options.PERMISSION_CATEGORY_ROLE"
        />
      </gl-tabs>
    </template>
  </crud-component>
</template>
