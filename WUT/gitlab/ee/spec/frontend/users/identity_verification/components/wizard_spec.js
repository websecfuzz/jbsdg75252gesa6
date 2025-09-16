import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import { visitUrl } from '~/lib/utils/url_utility';
import axios from '~/lib/utils/axios_utils';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import { HTTP_STATUS_OK, HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import IdentityVerificationWizard from 'ee/users/identity_verification/components/wizard.vue';
import VerificationStep from 'ee/users/identity_verification/components/verification_step.vue';
import CreditCardVerification from 'ee/users/identity_verification/components/credit_card_verification.vue';
import PhoneVerification from 'ee/users/identity_verification/components/phone_verification.vue';
import EmailVerification from 'ee/users/identity_verification/components/email_verification.vue';
import { I18N_GENERIC_ERROR } from 'ee/users/identity_verification/constants';
import { stubExperiments } from 'helpers/experimentation_helper';
import { getExperimentData } from '~/experimentation/utils';
import GitlabExperiment from '~/experimentation/components/gitlab_experiment.vue';

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility', () => {
  const originalModule = jest.requireActual('~/lib/utils/url_utility');

  return {
    ...originalModule,
    visitUrl: jest.fn().mockName('visitUrlMock'),
  };
});

describe('IdentityVerificationWizard', () => {
  let wrapper;
  let axiosMock;

  const DEFAULT_PROPS = { username: 'test_user123' };
  const DEFAULT_PROVIDE = {
    verificationStatePath: '/users/identity_verification/verification_state',
    successfulVerificationPath: '/users/identity_verification/success',
    phoneExemptionPath: '/users/identity_verification/toggle_phone_exemption',
  };

  const verificationStatePath = `${DEFAULT_PROVIDE.verificationStatePath}?no_cache=1`;

  const createComponent = ({ provide } = { provide: {} }) => {
    wrapper = shallowMount(IdentityVerificationWizard, {
      propsData: DEFAULT_PROPS,
      provide: { ...DEFAULT_PROVIDE, ...provide },
      stubs: { GitlabExperiment },
    });
  };

  const findSteps = () => wrapper.findAllComponents(VerificationStep);
  const findHeader = () => wrapper.find('h2');
  const findDescription = () => wrapper.find('p');

  const buildVerificationStateResponse = (mockState) => ({
    verification_methods: Object.keys(mockState),
    verification_state: mockState,
    methods_requiring_arkose_challenge: [],
  });

  const mockVerificationState = (mockState) => {
    axiosMock
      .onGet(verificationStatePath)
      .replyOnce(HTTP_STATUS_OK, buildVerificationStateResponse(mockState));
  };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.restore();
    createAlert.mockClear();
  });

  describe('Default', () => {
    beforeEach(async () => {
      mockVerificationState({ credit_card: false, phone: false, email: false });
      createComponent();
      await waitForPromises();
    });

    it('displays the header', () => {
      expect(findHeader().text()).toBe('Help us keep GitLab secure');
    });

    it('displays the description', () => {
      expect(findDescription().text()).toBe(
        `You are signed in as ${DEFAULT_PROPS.username}. For added security, you'll need to verify your identity in a few quick steps.`,
      );
    });

    it('renders the correct verification method components in order', () => {
      expect(findSteps()).toHaveLength(3);
      expect(findSteps().at(0).findComponent(CreditCardVerification).exists()).toBe(true);
      expect(findSteps().at(1).findComponent(PhoneVerification).exists()).toBe(true);
      expect(findSteps().at(2).findComponent(EmailVerification).exists()).toBe(true);
    });

    it('renders steps with correct number and title', () => {
      expect(findSteps().at(0).props('title')).toBe('Step 1: Verify a payment method');
      expect(findSteps().at(1).props('title')).toBe('Step 2: Verify phone number');
      expect(findSteps().at(2).props('title')).toBe('Step 3: Verify email address');
    });
  });

  describe('Verification method components requireChallenge prop', () => {
    beforeEach(async () => {
      const response = {
        ...buildVerificationStateResponse({ email: false, credit_card: false, phone: false }),
        methods_requiring_arkose_challenge: ['credit_card'],
      };

      axiosMock.onGet(verificationStatePath).replyOnce(HTTP_STATUS_OK, response);

      createComponent();
      await waitForPromises();
    });

    it('has the correct value', () => {
      expect(wrapper.findComponent(EmailVerification).props('requireChallenge')).toBeUndefined();
      expect(wrapper.findComponent(CreditCardVerification).props('requireChallenge')).toBe(true);
      expect(wrapper.findComponent(PhoneVerification).props('requireChallenge')).toBe(false);
    });
  });

  describe('Active verification step', () => {
    describe('when all steps are incomplete', () => {
      beforeEach(async () => {
        mockVerificationState({ credit_card: false, phone: false, email: false });
        createComponent();
        await waitForPromises();
      });

      it('is the first step', () => {
        expect(findSteps().at(0).props('isActive')).toBe(true);
        expect(findSteps().at(1).props('isActive')).toBe(false);
      });
    });

    describe('when some steps are complete', () => {
      beforeEach(async () => {
        mockVerificationState({ credit_card: true, phone: false, email: true });
        createComponent();
        await waitForPromises();
      });

      it('shows the incomplete steps at the end', () => {
        expect(findSteps().at(0).props('isActive')).toBe(false);
        expect(findSteps().at(1).props('isActive')).toBe(false);
        expect(findSteps().at(2).props('isActive')).toBe(true);

        expect(findSteps().at(0).props('title')).toBe('Step 1: Verify a payment method');
        expect(findSteps().at(1).props('title')).toBe('Step 2: Verify email address');
        expect(findSteps().at(2).props('title')).toBe('Step 3: Verify phone number');
      });
    });

    describe('when all steps are complete', () => {
      beforeEach(async () => {
        mockVerificationState({ credit_card: true, phone: true, email: true });
        createComponent();
        await waitForPromises();
      });

      it('shows all steps as completed', () => {
        expect(findSteps().at(0).props('completed')).toBe(true);
        expect(findSteps().at(1).props('completed')).toBe(true);
        expect(findSteps().at(2).props('completed')).toBe(true);
      });
    });
  });

  describe('Progression of active step', () => {
    const expectMethodToBeActive = (activeMethodNumber, stepWrappers) => {
      stepWrappers.forEach((stepWrapper, index) => {
        const shouldBeActive = index + 1 === activeMethodNumber;
        expect(stepWrapper.props('isActive')).toBe(shouldBeActive);
      });
    };

    const expectAllMethodsToBeCompleted = (stepWrappers) => {
      stepWrappers.forEach((stepWrapper) => {
        expect(stepWrapper.props('completed')).toBe(true);
      });
    };

    beforeEach(async () => {
      mockVerificationState({ credit_card: false, phone: false, email: false });
      createComponent();
      await waitForPromises();
    });

    it('goes from first to last one step at a time and redirects after all are completed', async () => {
      const setTimeoutSpy = jest.spyOn(global, 'setTimeout');

      expectMethodToBeActive(1, findSteps().wrappers);

      findSteps().at(0).findComponent(CreditCardVerification).vm.$emit('completed');
      await nextTick();

      expect(setTimeoutSpy).not.toHaveBeenCalled();

      expectMethodToBeActive(2, findSteps().wrappers);

      findSteps().at(1).findComponent(PhoneVerification).vm.$emit('completed');
      await nextTick();

      expectMethodToBeActive(3, findSteps().wrappers);

      findSteps().at(2).findComponent(EmailVerification).vm.$emit('completed');
      await nextTick();

      expectAllMethodsToBeCompleted(findSteps().wrappers);

      jest.runAllTimers();

      expect(setTimeoutSpy).toHaveBeenCalledTimes(1);
      expect(visitUrl).toHaveBeenCalledWith(DEFAULT_PROVIDE.successfulVerificationPath);
    });
  });

  describe('when the `exemptionRequested` event is fired from the phone verification step', () => {
    beforeEach(async () => {
      mockVerificationState({ phone: false, email: false });
      createComponent();
      await waitForPromises();
    });

    it('renders the credit card verification step instead of the phone verification step', async () => {
      axiosMock.onPatch(DEFAULT_PROVIDE.phoneExemptionPath).reply(HTTP_STATUS_OK, {
        verification_methods: ['credit_card', 'email'],
        verification_state: { credit_card: false, email: true },
      });

      wrapper.findComponent(PhoneVerification).vm.$emit('exemptionRequested');

      await axios.waitForAll();

      expect(wrapper.findComponent(PhoneVerification).exists()).toBe(false);
      expect(wrapper.findComponent(CreditCardVerification).exists()).toBe(true);
    });

    describe('when there is an error requesting a phone exemption', () => {
      it('renders the credit card verification step instead of the phone verification step', async () => {
        axiosMock.onPatch(DEFAULT_PROVIDE.phoneExemptionPath).reply(HTTP_STATUS_BAD_REQUEST, {});

        wrapper.findComponent(PhoneVerification).vm.$emit('exemptionRequested');

        await axios.waitForAll();

        expect(createAlert).toHaveBeenCalledWith({
          message: I18N_GENERIC_ERROR,
          captureError: true,
          error: expect.any(Error),
        });
      });
    });
  });

  describe('A verification component emits set-verification-state', () => {
    beforeEach(async () => {
      mockVerificationState({ email: false });
      createComponent();
      await waitForPromises();
    });

    it('executes setVerificationState', async () => {
      expect(findSteps().at(0).props('completed')).toBe(false);

      findSteps()
        .at(0)
        .findComponent(EmailVerification)
        .vm.$emit('set-verification-state', buildVerificationStateResponse({ email: true }));

      await nextTick();

      expect(findSteps().at(0).props('completed')).toBe(true);
    });
  });

  describe('with lightweight_trial_registration_redesign experiment candidate', () => {
    beforeEach(async () => {
      mockVerificationState({ credit_card: false, phone: false, email: false });
      stubExperiments({ lightweight_trial_registration_redesign: 'candidate' });

      createComponent();
      await waitForPromises();
    });

    it('sets the correct experiment data', () => {
      expect(getExperimentData('lightweight_trial_registration_redesign')).toEqual({
        experiment: 'lightweight_trial_registration_redesign',
        variant: 'candidate',
      });
    });

    it('renders the GitLab logo', () => {
      const logoImage = wrapper.find('img');

      expect(logoImage.exists()).toBe(true);
      expect(logoImage.attributes().alt).toBe('GitLab logo');
    });

    it('displays the shortened description', () => {
      expect(findDescription().text()).toBe(
        `For added security, you'll need to verify your identity.`,
      );
    });

    it('renders steps with title, and passing correct total steps', () => {
      const VERIFICATION_STEPS = [
        { title: 'Payment Method Verification', index: 0 },
        { title: 'Phone Number Verification', index: 1 },
        { title: 'Email Verification', index: 2 },
      ];

      VERIFICATION_STEPS.forEach((step, index) => {
        expect(findSteps().at(index).props('title')).toBe(step.title);
        expect(findSteps().at(index).props('totalSteps')).toBe(VERIFICATION_STEPS.length);
        expect(findSteps().at(index).props('stepIndex')).toBe(step.index);
      });
    });
  });
});
