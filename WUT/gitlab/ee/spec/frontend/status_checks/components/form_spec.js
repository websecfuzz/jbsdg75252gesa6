import { GlAlert, GlFormGroup, GlFormInput } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import StatusCheckForm from 'ee/status_checks/components/status_check_form.vue';
import { NAME_TAKEN_SERVER_ERROR, URL_TAKEN_SERVER_ERROR } from 'ee/status_checks/constants';
import ProtectedBranchesSelector from 'ee/vue_shared/components/branches_selector/protected_branches_selector.vue';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { TEST_PROTECTED_BRANCHES } from 'ee_jest/vue_shared/components/branches_selector/mock_data';

const projectId = '1';
const statusCheck = {
  protectedBranches: TEST_PROTECTED_BRANCHES,
  name: 'Foo',
  externalUrl: 'https://foo.com',
  sharedSecret: 'secret',
};
const sentryError = new Error('Network error');

describe('Status checks form', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(StatusCheckForm, {
      propsData: {
        projectId,
        ...props,
      },
      stubs: {
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback'],
        }),
        GlFormInput: stubComponent(GlFormInput, {
          props: ['state', 'disabled', 'value'],
          template: `<input />`,
        }),
        BranchesSelect: stubComponent(ProtectedBranchesSelector),
      },
    });
  };

  const findForm = () => wrapper.find('form');
  const findNameInput = () => wrapper.findByTestId('name');
  const findNameValidation = () => wrapper.findByTestId('name-group');
  const findProtectedBranchesSelector = () => wrapper.findComponent(ProtectedBranchesSelector);
  const findUrlInput = () => wrapper.findByTestId('url');
  const findUrlValidation = () => wrapper.findByTestId('url-group');
  const findBranchesValidation = () => wrapper.findByTestId('branches-group');
  const findSharedSecretInput = () => wrapper.findByTestId('shared-secret');
  const findHmacEditButton = () => wrapper.findByTestId('override-hmac');
  const findBranchesErrorAlert = () => wrapper.findComponent(GlAlert);

  const findValidations = () => [
    findNameValidation(),
    findUrlValidation(),
    findBranchesValidation(),
  ];
  const inputsAreValid = () => findValidations().every((x) => x.props('state'));

  describe('initialization', () => {
    it('shows empty inputs when no initial data is given', () => {
      createWrapper();

      expect(inputsAreValid()).toBe(true);
      expect(findNameInput().props('value')).toBe('');
      expect(findProtectedBranchesSelector().props('selectedBranches')).toStrictEqual([]);
      expect(findProtectedBranchesSelector().props('multiple')).toBe(true);
      expect(findSharedSecretInput().exists()).toBe(true);
      expect(findUrlInput().props('value')).toBe('');
      expect(findHmacEditButton().exists()).toBe(false);
    });

    it('shows filled inputs when initial data is given', () => {
      createWrapper({ statusCheck });

      expect(inputsAreValid()).toBe(true);
      expect(findNameInput().props('value')).toBe(statusCheck.name);
      expect(findProtectedBranchesSelector().props('selectedBranches')).toStrictEqual(
        statusCheck.protectedBranches,
      );
      expect(findUrlInput().props('value')).toBe(statusCheck.externalUrl);
    });
  });

  describe('validation', () => {
    it('shows the validation messages if invalid on submission', async () => {
      createWrapper({ branches: ['abc'] });

      await findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toBe(undefined);
      expect(inputsAreValid()).toBe(false);
      expect(findNameValidation().props('invalidFeedback')).toBe('Please provide a name.');
      expect(findBranchesValidation().props('invalidFeedback')).toBe(
        'Select a valid target branch.',
      );
      expect(findUrlValidation().props('invalidFeedback')).toBe('Please provide a valid URL.');
    });

    it.each`
      hmac     | description
      ${false} | ${'Provide a shared secret. This secret is used to authenticate requests for a status check using HMAC.'}
      ${true}  | ${'A secret is currently configured for this status check.'}
    `('disables HMAC secret field when HMAC is enabled', ({ hmac, description }) => {
      createWrapper({
        statusCheck: { ...statusCheck, hmac },
      });

      expect(Boolean(findSharedSecretInput().attributes('disabled'))).toBe(hmac);
      expect(findSharedSecretInput().attributes('description')).toBe(description);
    });

    it('shows the invalid URL error if the URL is unsafe', async () => {
      createWrapper({
        statusCheck: { ...statusCheck, externalUrl: 'ftp://foo.com' },
      });

      await findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toBe(undefined);
      expect(inputsAreValid()).toBe(false);
      expect(findUrlValidation().props('invalidFeedback')).toBe('Please provide a valid URL.');
    });

    it('shows the serverValidationErrors if given', async () => {
      createWrapper({
        serverValidationErrors: [NAME_TAKEN_SERVER_ERROR, URL_TAKEN_SERVER_ERROR],
        statusCheck,
      });

      await findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toContainEqual([
        {
          branches: statusCheck.protectedBranches,
          name: statusCheck.name,
          url: statusCheck.externalUrl,
          sharedSecret: statusCheck.sharedSecret,
          overrideHmac: false,
        },
      ]);

      expect(inputsAreValid()).toBe(false);
      expect(findNameValidation().props('invalidFeedback')).toBe('Name is already taken.');
      expect(findUrlValidation().props('invalidFeedback')).toBe(
        'The specified external API is already in use by another status check.',
      );
    });

    it('does not show any errors if the values are valid', async () => {
      createWrapper({ statusCheck });

      await findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toContainEqual([
        {
          branches: statusCheck.protectedBranches,
          name: statusCheck.name,
          url: statusCheck.externalUrl,
          sharedSecret: 'secret',
          overrideHmac: false,
        },
      ]);
      expect(inputsAreValid()).toBe(true);
    });
  });

  describe('branches error alert', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
      createWrapper();
    });

    it('sends the error to sentry', () => {
      findProtectedBranchesSelector().vm.$emit('apiError', {
        hasErrored: true,
        error: sentryError,
      });

      expect(Sentry.captureException.mock.calls[0][0]).toStrictEqual(sentryError);
    });

    it('shows the alert', async () => {
      expect(findBranchesErrorAlert().exists()).toBe(false);

      await findProtectedBranchesSelector().vm.$emit('apiError', {
        hasErrored: true,
        error: sentryError,
      });

      expect(findBranchesErrorAlert().exists()).toBe(true);
    });

    it('hides the alert if the apiError is reset', async () => {
      await findProtectedBranchesSelector().vm.$emit('apiError', {
        hasErrored: true,
        error: sentryError,
      });
      expect(findBranchesErrorAlert().exists()).toBe(true);

      await findProtectedBranchesSelector().vm.$emit('apiError', { hasErrored: false });
      expect(findBranchesErrorAlert().exists()).toBe(false);
    });

    it('only calls sentry once while the branches api is failing', () => {
      findProtectedBranchesSelector().vm.$emit('apiError', {
        hasErrored: true,
        error: sentryError,
      });
      findProtectedBranchesSelector().vm.$emit('apiError', {
        hasErrored: true,
        error: sentryError,
      });

      expect(Sentry.captureException.mock.calls).toEqual([[sentryError]]);
    });
  });

  describe('override hmac secret', () => {
    it('overrides existing shared secret', async () => {
      createWrapper({ statusCheck: { ...statusCheck, hmac: true } });

      expect(findHmacEditButton().exists()).toBe(true);
      expect(Boolean(findSharedSecretInput().attributes('disabled'))).toBe(true);
      expect(findHmacEditButton().props('disabled')).toBe(false);
      expect(findHmacEditButton().attributes('title')).toBe(
        'Enter a new value to overwrite the current secret.',
      );

      await findHmacEditButton().vm.$emit('click');

      expect(findHmacEditButton().props('disabled')).toBe(true);
      expect(Boolean(findSharedSecretInput().attributes('disabled'))).toBe(false);
      expect(findSharedSecretInput().attributes('description')).toBe(
        'Enter a new value to overwrite the current secret.',
      );

      await findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toContainEqual([
        {
          branches: statusCheck.protectedBranches,
          name: statusCheck.name,
          url: statusCheck.externalUrl,
          sharedSecret: 'secret',
          overrideHmac: true,
        },
      ]);
    });

    it('validates shared secret when override is enabled', async () => {
      createWrapper({ statusCheck: { ...statusCheck, sharedSecret: '', hmac: true } });

      await findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toContainEqual([
        {
          branches: statusCheck.protectedBranches,
          name: statusCheck.name,
          url: statusCheck.externalUrl,
          sharedSecret: '',
          overrideHmac: false,
        },
      ]);
      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(findSharedSecretInput().props('state')).toBe(true);

      await findHmacEditButton().vm.$emit('click');

      await findForm().trigger('submit');

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(findSharedSecretInput().props('state')).toBe(false);
    });
  });
});
