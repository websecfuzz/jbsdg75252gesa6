<script>
import { GlModal } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';

const i18ns = {
  title: s__('SecurityLabels|Delete security label?'),
  cancelButton: __('Cancel'),
  deleteButton: s__('SecurityLabels|Delete security label'),
  deleteMessageTemplate: s__(
    'SecurityLabels|Deleting the "%{labelName}" Security Label will permanently remove it from its category and any projects where it is applied. This action cannot be undone.',
  ),
};

export default {
  components: {
    GlModal,
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    label: {
      type: Object,
      required: true,
    },
  },
  computed: {
    deleteMessage() {
      return sprintf(i18ns.deleteMessageTemplate, {
        labelName: this.label.name,
      });
    },
  },
  methods: {
    onConfirm() {
      this.$emit('confirm');
    },
    onCancel() {
      this.$emit('cancel');
    },
  },
  i18ns,
};
</script>

<template>
  <gl-modal
    :visible="visible"
    modal-id="delete-security-label-modal"
    :title="$options.i18ns.title"
    :ok-title="$options.i18ns.deleteButton"
    :cancel-title="$options.i18ns.cancelButton"
    ok-variant="danger"
    @hide="onCancel"
    @ok="onConfirm"
  >
    <p>
      {{ deleteMessage }}
    </p>
  </gl-modal>
</template>
