<script>
import { GlDrawer, GlButton } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { DRAWER_MODES } from './constants';
import SecurityLabelForm from './label_form.vue';
import LabelDeleteModal from './label_delete_modal.vue';

export default {
  components: {
    GlDrawer,
    GlButton,
    SecurityLabelForm,
    LabelDeleteModal,
  },
  DRAWER_Z_INDEX,
  i18n: {
    addLabelTitle: s__('SecurityLabels|Add security label'),
    editLabelTitle: s__('SecurityLabels|Edit security label'),
    updateLabelButton: s__('SecurityLabels|Update label'),
    createLabelButton: s__('SecurityLabels|Add label'),
    cancelButton: s__('SecurityLabels|Cancel'),
    deleteButton: s__('SecurityLabels|Delete'),
  },
  data() {
    return {
      isOpen: false,
      mode: DRAWER_MODES.ADD,
      label: {},
      showDeleteModal: false,
    };
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    drawerTitle() {
      return this.mode === DRAWER_MODES.EDIT
        ? this.$options.i18n.editLabelTitle
        : this.$options.i18n.addLabelTitle;
    },
    primaryButtonLabel() {
      return this.mode === DRAWER_MODES.EDIT
        ? this.$options.i18n.updateLabelButton
        : this.$options.i18n.createLabelButton;
    },
    secondaryButtonLabel() {
      return this.$options.i18n.cancelButton;
    },
    deleteButtonLabel() {
      return this.$options.i18n.deleteButton;
    },
    isAddMode() {
      return this.mode === DRAWER_MODES.ADD;
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- `open()` is called from the parent component
    open(mode = DRAWER_MODES.ADD, label = {}) {
      this.label = label;
      this.mode = mode;
      this.isOpen = true;
    },
    close() {
      this.isOpen = false;
    },
    onSubmit(payload) {
      this.$emit('saved', payload);
      this.close();
    },
    onDelete() {
      this.$emit('delete', this.label);
      this.showDeleteModal = false;
      this.close();
    },
  },
  DRAWER_MODES,
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :header-sticky="true"
    :open="isOpen"
    size="md"
    class="security-label-form-drawer"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="close"
  >
    <template #title>
      <h4 class="gl-my-0 gl-mr-3 gl-text-size-h2">{{ drawerTitle }}</h4>
    </template>

    <security-label-form ref="form" :label="label" :mode="mode" @saved="onSubmit" @cancel="close" />
    <label-delete-modal
      :visible="showDeleteModal"
      :label="label"
      @confirm="onDelete"
      @cancel="showDeleteModal = false"
    />

    <template #footer>
      <div class="flex-fill gl-align-items-center gl-flex gl-justify-between">
        <div class="gl-display-flex gl-gap-3">
          <gl-button
            category="primary"
            variant="confirm"
            data-testid="submit-btn"
            @click="$refs.form.onSubmit()"
          >
            {{ primaryButtonLabel }}
          </gl-button>
          <gl-button data-testid="cancel-btn" class="gl-ml-2" @click="close">
            {{ secondaryButtonLabel }}
          </gl-button>
        </div>

        <gl-button
          v-if="!isAddMode"
          category="primary"
          variant="danger"
          data-testid="delete-btn"
          @click="showDeleteModal = true"
        >
          {{ deleteButtonLabel }}
        </gl-button>
      </div>
    </template>
  </gl-drawer>
</template>
