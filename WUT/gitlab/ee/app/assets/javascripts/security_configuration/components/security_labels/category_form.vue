<script>
import {
  GlBadge,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadioGroup,
  GlFormRadio,
  GlIcon,
  GlTableLite,
  GlLabel,
  GlButton,
  GlTooltipDirective,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLink,
} from '@gitlab/ui';
import { __ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { defaultCategory } from './constants';

export default {
  components: {
    GlBadge,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
    GlTableLite,
    GlLabel,
    GlButton,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    CrudComponent,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    securityLabels: {
      type: Array,
      required: true,
    },
    category: {
      type: Object,
      required: false,
      default: () => defaultCategory,
    },
  },
  computed: {
    isNew() {
      return !this.category?.id;
    },
    isLocked() {
      return !this.category?.canEditCategory && !this.category?.canEditLabels;
    },
    isLimited() {
      return !this.category?.canEditCategory && this.category?.canEditLabels;
    },
    isCategoryEditable() {
      return this.category?.canEditCategory || this.isNew;
    },
    areLabelsEditable() {
      return this.category?.canEditLabels || this.isNew;
    },
    categoryName() {
      return this.category?.name;
    },
    categoryDescription() {
      return this.category?.description;
    },
    labels() {
      return this.category?.id ? this.securityLabels : [];
    },
  },
  labelsTableFields: [
    {
      key: 'name',
      label: __('Label'),
      // eslint-disable-next-line @gitlab/require-i18n-strings
      tdClass: '!gl-border-b-0 gl-w-1/5',
      // eslint-disable-next-line @gitlab/require-i18n-strings
      thClass: '!gl-border-t-0 gl-w-1/5',
    },
    {
      key: 'description',
      label: __('Description'),
      tdClass: '!gl-border-b-0 gl-w-[55%]',
      thClass: '!gl-border-t-0 gl-w-[55%]',
    },
    {
      key: 'usedBy',
      label: __('Used by'),
      tdClass: '!gl-border-b-0 gl-w-[15%]',
      thClass: '!gl-border-t-0 gl-w-[15%]',
    },
    {
      key: 'actions',
      label: '',
      tdClass: '!gl-border-b-0 gl-w-[10%]',
      thClass: '!gl-border-t-0 gl-w-[10%]',
    },
  ],
  editItem: {
    text: __('Edit'),
  },
};
</script>
<template>
  <div>
    <div class="gl-p-6">
      <div class="gl-float-right">
        <gl-badge
          v-if="isLocked"
          v-gl-tooltip="
            s__(
              'SecurityLabels|You cannot delete or edit this category. You cannot modify the labels.',
            )
          "
          icon="lock"
        >
          {{ s__('SecurityLabels|Category locked') }}
        </gl-badge>
        <gl-badge
          v-else-if="isLimited"
          v-gl-tooltip="
            s__('SecurityLabels|You cannot delete this category, but you can edit the labels.')
          "
          icon="pencil"
        >
          {{ s__('SecurityLabels|Limited edits allowed') }}
        </gl-badge>
      </div>
      <h3 class="gl-heading-3">{{ s__('SecurityLabels|Category details') }}</h3>
      <p>{{ s__('SecurityLabels|View category settings and associated labels.') }}</p>
      <gl-form>
        <gl-form-group :label="__('Name')">
          <gl-form-input v-if="isCategoryEditable" :value="categoryName" />
          <span v-else>{{ categoryName }}</span>
        </gl-form-group>
        <gl-form-group :label="__('Description')">
          <gl-form-textarea v-if="isCategoryEditable" :value="categoryDescription" />
          <span v-else>{{ categoryDescription }}</span>
        </gl-form-group>
        <gl-form-group>
          <template #label>
            {{ s__('SecurityLabels|Selection type') }}
            <gl-icon
              v-gl-tooltip="
                s__(
                  'SecurityLabels|You cannot change the selection type after the category is created. To use a different selection type, create a new category.',
                )
              "
              variant="info"
              name="information-o"
            />
          </template>
          <gl-form-radio-group v-if="isNew">
            <gl-form-radio :value="false">
              {{ s__('SecurityLabels|Single selection') }}
            </gl-form-radio>
            <gl-form-radio :value="true">
              {{ s__('SecurityLabels|Multiple selection') }}
            </gl-form-radio>
          </gl-form-radio-group>
          <span v-else>{{
            category.multipleSelection ? 'Multiple selection' : 'Single selection'
          }}</span>
        </gl-form-group>
        <gl-button
          v-if="areLabelsEditable"
          category="secondary"
          variant="confirm"
          size="small"
          class="gl-float-right"
          @click="$emit('addLabel')"
        >
          {{ s__('SecurityLabels|Create label') }}
        </gl-button>
        <gl-form-group
          :description="s__('SecurityLabels|View the labels available in this category')"
        >
          <template #label>
            {{ __('Labels') }}
            <span class="gl-font-normal gl-text-subtle">
              <gl-icon name="label" />
              {{ labels.length }}
            </span>
          </template>
        </gl-form-group>
        <crud-component header-class="gl-hidden">
          <gl-table-lite :items="labels" :fields="$options.labelsTableFields" class="gl-mb-0">
            <template #cell(name)="{ item: { name, color } }">
              <gl-label :background-color="color" :title="name" />
            </template>
            <template #cell(usedBy)="{ item: { projectCount } }">
              <gl-link v-if="!isNaN(projectCount)">
                {{ n__('%d project', '%d projects', projectCount) }}
              </gl-link>
            </template>
            <template v-if="areLabelsEditable" #cell(actions)="{ item }">
              <gl-disclosure-dropdown category="tertiary" icon="ellipsis_v" no-caret>
                <gl-disclosure-dropdown-item
                  :item="$options.editItem"
                  @action="$emit('editLabel', item)"
                />
              </gl-disclosure-dropdown>
            </template>
          </gl-table-lite>
        </crud-component>
      </gl-form>
    </div>
    <div v-if="!isLocked" class="gl-border-t gl-sticky gl-bottom-0 gl-w-full gl-bg-default gl-p-6">
      <gl-button category="primary" variant="confirm">
        {{ s__('SecurityLabels|Save changes') }}
      </gl-button>
    </div>
  </div>
</template>
