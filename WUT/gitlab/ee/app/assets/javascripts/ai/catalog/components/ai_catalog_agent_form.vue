<script>
import { uniqueId } from 'lodash';
import { GlButton, GlForm, GlFormFields, GlFormTextarea } from '@gitlab/ui';
import {
  MAX_LENGTH_NAME,
  MAX_LENGTH_DESCRIPTION,
  MAX_LENGTH_PROMPT,
} from 'ee/ai/catalog/constants';
import { __, s__ } from '~/locale';
import { createFieldValidators } from '../utils';
import AiCatalogFormButtons from './ai_catalog_form_buttons.vue';

const tmpProjectId = 'gid://gitlab/Project/1000000';

export default {
  components: {
    AiCatalogFormButtons,
    GlButton,
    GlForm,
    GlFormFields,
    GlFormTextarea,
  },
  props: {
    mode: {
      type: String,
      required: true,
      validator: (mode) => ['edit', 'create'].includes(mode),
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    projectId: {
      type: String,
      required: false,
      default: tmpProjectId,
    },
    name: {
      type: String,
      required: false,
      default: '',
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    systemPrompt: {
      type: String,
      required: false,
      default: '',
    },
    userPrompt: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      formValues: {
        projectId: this.projectId,
        name: this.name,
        description: this.description,
        systemPrompt: this.systemPrompt,
        userPrompt: this.userPrompt,
      },
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-agent-form-');
    },
    submitButtonText() {
      if (this.mode === 'create') {
        return s__('AICatalog|Create agent');
      }
      // eslint-disable-next-line @gitlab/require-i18n-strings
      return `${s__('AICatalog|Save changes')} (Coming soon)`;
    },
    fields() {
      return {
        projectId: {
          label: s__('AICatalog|Project ID'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Project ID is required.'),
          }),
          inputAttrs: {
            'data-testid': 'agent-form-input-project-id',
            placeholder: tmpProjectId,
            disabled: this.mode === 'edit',
          },
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Select a project for your AI agent to be associated with.',
            ),
          },
        },
        name: {
          label: __('Name'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Name is required.'),
            maxLength: MAX_LENGTH_NAME,
          }),
          inputAttrs: {
            'data-testid': 'agent-form-input-name',
            placeholder: s__('AICatalog|e.g., Research Assistant, Creative Writer, Code Helper'),
          },
          groupAttrs: {
            labelDescription: s__('AICatalog|Choose a memorable name for your AI agent.'),
          },
        },
        description: {
          label: __('Description'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|Description is required.'),
            maxLength: MAX_LENGTH_DESCRIPTION,
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Briefly describe what this agent is designed to do and its key capabilities.',
            ),
          },
        },
        systemPrompt: {
          label: s__('AICatalog|System Prompt'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|System Prompt is required.'),
            maxLength: MAX_LENGTH_PROMPT,
          }),
          groupAttrs: {
            labelDescription: s__(
              "AICatalog|Define the agent's personality, expertise, and behavioral guidelines. This shapes how the agent responds and approaches tasks.",
            ),
          },
        },
        userPrompt: {
          label: s__('AICatalog|User Prompt'),
          validators: createFieldValidators({
            requiredLabel: s__('AICatalog|User Prompt is required.'),
            maxLength: MAX_LENGTH_PROMPT,
          }),
          groupAttrs: {
            labelDescription: s__(
              'AICatalog|Provide default instructions or context that will be included with every user interaction.',
            ),
          },
        },
      };
    },
  },
  methods: {
    handleSubmit() {
      const trimmedFormValues = {
        projectId: this.formValues.projectId.trim(),
        name: this.formValues.name.trim(),
        description: this.formValues.description.trim(),
        systemPrompt: this.formValues.systemPrompt.trim(),
        userPrompt: this.formValues.userPrompt.trim(),
      };
      this.$emit('submit', trimmedFormValues);
    },
  },
};
</script>
<template>
  <gl-form :id="formId" class="gl-max-w-lg" @submit.prevent>
    <gl-form-fields v-model="formValues" :form-id="formId" :fields="fields" @submit="handleSubmit">
      <template #input(description)="{ id, input, value, blur, validation }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :placeholder="
            s__('AICatalog|This agent specializes in... It can help you with... Best suited for...')
          "
          :state="validation.state"
          :value="value"
          data-testid="agent-form-textarea-description"
          @blur="blur"
          @update="input"
        />
      </template>
      <template #input(systemPrompt)="{ id, input, value, blur, validation }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :placeholder="
            s__(
              'AICatalog|You are an expert in [domain]. Your communication style is [style]. When helping users, you should always... Your key strengths include... You approach problems by...',
            )
          "
          :state="validation.state"
          :value="value"
          data-testid="agent-form-textarea-system-prompt"
          @blur="blur"
          @update="input"
        />
      </template>
      <template #input(userPrompt)="{ id, input, value, blur, validation }">
        <gl-form-textarea
          :id="id"
          :no-resize="false"
          :placeholder="
            s__(
              'AICatalog|Please consider my background in... When explaining concepts, use... My preferred format for responses is... Always include...',
            )
          "
          :rows="10"
          :state="validation.state"
          :value="value"
          data-testid="agent-form-textarea-user-prompt"
          @blur="blur"
          @update="input"
        />
      </template>
    </gl-form-fields>
    <ai-catalog-form-buttons :is-disabled="isLoading">
      <gl-button
        class="js-no-auto-disable"
        type="submit"
        variant="confirm"
        category="primary"
        data-testid="agent-form-submit-button"
        :loading="isLoading"
      >
        {{ submitButtonText }}
      </gl-button>
    </ai-catalog-form-buttons>
  </gl-form>
</template>
