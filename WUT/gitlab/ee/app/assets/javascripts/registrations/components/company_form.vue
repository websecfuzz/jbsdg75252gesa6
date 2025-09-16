<script>
import { GlForm, GlButton, GlFormGroup, GlFormInput } from '@gitlab/ui';
import {
  LEADS_COMPANY_NAME_LABEL,
  LEADS_FIRST_NAME_LABEL,
  LEADS_LAST_NAME_LABEL,
  LEADS_PHONE_NUMBER_LABEL,
} from 'ee/vue_shared/leads/constants';
import csrf from '~/lib/utils/csrf';
import { s__ } from '~/locale';
import FormErrorTracker from '~/pages/shared/form_error_tracker';
import CountryOrRegionSelector from 'ee/trials/components/country_or_region_selector.vue';
import { TRIAL_PHONE_DESCRIPTION } from 'ee/trials/constants';
import { trackCompanyForm } from 'ee/google_tag_manager';

export default {
  csrf,
  components: {
    GlForm,
    GlButton,
    GlFormGroup,
    GlFormInput,
    CountryOrRegionSelector,
  },
  inject: {
    user: {
      default: {},
    },
    submitPath: {
      type: String,
      default: '',
    },
    showFormFooter: {
      type: Boolean,
    },
    trackActionForErrors: {
      type: String,
      required: false,
    },
  },
  computed: {
    formSubmitText() {
      if (this.showFormFooter) {
        return s__('Trial|Continue with trial');
      }

      return s__('Trial|Continue');
    },
  },
  mounted() {
    new FormErrorTracker(); // eslint-disable-line no-new
  },
  methods: {
    trackCompanyForm() {
      trackCompanyForm('ultimate_trial', this.user.emailDomain);
    },
  },
  i18n: {
    firstNameLabel: LEADS_FIRST_NAME_LABEL,
    lastNameLabel: LEADS_LAST_NAME_LABEL,
    companyNameLabel: LEADS_COMPANY_NAME_LABEL,
    phoneNumberLabel: LEADS_PHONE_NUMBER_LABEL,
    phoneNumberDescription: TRIAL_PHONE_DESCRIPTION,
  },
};
</script>

<template>
  <gl-form
    :action="submitPath"
    class="gl-show-field-errors gl-border-1 gl-border-solid gl-border-default gl-p-6"
    method="post"
    @submit="trackCompanyForm"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <div v-show="user.showNameFields" class="gl-flex gl-flex-col sm:gl-flex-row">
      <gl-form-group
        :label="$options.i18n.firstNameLabel"
        label-size="sm"
        label-for="first_name"
        class="gl-mr-5 gl-w-full sm:gl-w-1/2"
      >
        <gl-form-input
          id="first_name"
          :value="user.firstName"
          name="first_name"
          class="js-track-error"
          data-testid="first_name"
          :data-track-action-for-errors="trackActionForErrors"
          required
        />
      </gl-form-group>
      <gl-form-group
        :label="$options.i18n.lastNameLabel"
        label-size="sm"
        label-for="last_name"
        class="gl-w-full sm:gl-w-1/2"
      >
        <gl-form-input
          id="last_name"
          :value="user.lastName"
          name="last_name"
          class="js-track-error"
          data-testid="last_name"
          :data-track-action-for-errors="trackActionForErrors"
          required
        />
      </gl-form-group>
    </div>
    <gl-form-group :label="$options.i18n.companyNameLabel" label-size="sm" label-for="company_name">
      <gl-form-input
        id="company_name"
        :value="user.companyName"
        name="company_name"
        class="js-track-error"
        data-testid="company_name"
        :data-track-action-for-errors="trackActionForErrors"
        required
      />
    </gl-form-group>

    <country-or-region-selector
      :country="user.country"
      :state="user.state"
      data-testid="country"
      :track-action-for-errors="trackActionForErrors"
      required
    />

    <gl-form-group
      :label="$options.i18n.phoneNumberLabel"
      label-size="sm"
      label-for="phone_number"
      optional
    >
      <gl-form-input
        id="phone_number"
        :value="user.phoneNumber"
        name="phone_number"
        type="tel"
        data-testid="phone_number"
        pattern="^(\+)*[0-9\-\s]+$"
        :title="$options.i18n.phoneNumberDescription"
      />
    </gl-form-group>
    <gl-button type="submit" variant="confirm" class="gl-w-full">
      {{ formSubmitText }}
    </gl-button>

    <div v-if="showFormFooter" class="gl-mt-4">
      <span data-testid="footer_description_text" class="gl-text-sm gl-text-subtle">
        {{
          s__(
            'Trial|Your free Ultimate & GitLab Duo Enterprise Trial lasts for 60 days. After this period, you can maintain a GitLab Free account forever, or upgrade to a paid plan.',
          )
        }}
      </span>
    </div>
  </gl-form>
</template>
