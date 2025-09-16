<script>
import { GlForm, GlFormGroup, GlFormInput, GlFormTextarea } from '@gitlab/ui';
import ColorPicker from '~/vue_shared/components/color_picker/color_picker.vue';
import { validateHexColor } from '~/lib/utils/color_utils';
import { s__ } from '~/locale';
import { DRAWER_MODES } from './constants';

const i18ns = {
  nameLabel: s__('SecurityLabels|Name'),
  descriptionLabel: s__('SecurityLabels|Description'),
  colorInputLabel: s__('SecurityLabels|Color'),
  nameRequired: s__('SecurityLabels|Name is required'),
  descriptionRequired: s__('SecurityLabels|Description is required'),
};

export default {
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
    ColorPicker,
  },
  props: {
    label: {
      type: Object,
      required: true,
    },
    // eslint-disable-next-line vue/no-unused-properties -- To be removed
    mode: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      name: this.label?.name || '',
      description: this.label?.description || '',
      color: this.label?.color || '#dc143c',
      validationState: {
        name: true,
        description: true,
      },
    };
  },
  methods: {
    isFormValid() {
      return Object.values(this.validationState).every(Boolean) && this.isValidColor();
    },
    validateName() {
      this.validationState.name = this.name.trim().length > 0;
    },
    validateDescription() {
      this.validationState.description = this.description.trim().length > 0;
    },
    onSubmit() {
      this.validateName();
      this.validateDescription();

      if (!this.isFormValid()) {
        return;
      }

      const payload = {
        id: this.label.id,
        name: this.name.trim(),
        description: this.description.trim(),
        color: this.color,
      };

      this.$emit('saved', payload);
    },
    isValidColor() {
      return Boolean(this.color) && validateHexColor(this.color);
    },
  },
  DRAWER_MODES,
  i18ns,
};
</script>

<template>
  <gl-form @submit.prevent="onSubmit">
    <gl-form-group
      :label="$options.i18ns.nameLabel"
      label-for="label-name"
      :state="validationState.name"
      :invalid-feedback="$options.i18ns.nameRequired"
    >
      <gl-form-input
        id="label-name"
        v-model="name"
        :state="validationState.name"
        :required="true"
        @input="validateName"
      />
    </gl-form-group>

    <gl-form-group
      :label="$options.i18ns.descriptionLabel"
      label-for="label-description"
      :state="validationState.description"
      :invalid-feedback="$options.i18ns.descriptionRequired"
    >
      <gl-form-textarea
        id="label-description"
        v-model="description"
        :no-resize="false"
        :state="validationState.description"
        :required="true"
        @input="validateDescription"
      />
    </gl-form-group>

    <color-picker
      v-model="color"
      :label="$options.i18ns.colorInputLabel"
      :state="isValidColor(color)"
    />
  </gl-form>
</template>
