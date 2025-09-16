import { shallowMount } from '@vue/test-utils';
import { GlFormRadio, GlFormGroup, GlSprintf } from '@gitlab/ui';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('DuoAvailabilityForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    return shallowMount(DuoAvailabilityForm, {
      stubs: {
        'gl-form-radio': GlFormRadio,
        'gl-sprintf': GlSprintf,
      },
      propsData: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        ...props,
      },
      provide: {
        areDuoSettingsLocked: false,
        cascadingSettingsData: {
          lockedByAncestor: false,
          lockedByApplicationSetting: false,
          ancestorNamespace: null,
        },
        isSaaS: true,
        ...provide,
      },
    });
  };

  const findFormRadioButtons = () => wrapper.findAllComponents(GlFormRadio);
  const findRadioButtonDescriptions = () => wrapper.findAll('.help-text');
  const findCascadingLockIcon = () => wrapper.findComponent(CascadingLockIcon);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);

  it('displays title', () => {
    wrapper = createComponent();
    expect(findFormGroup().attributes('label')).toContain('GitLab Duo availability');
  });

  it('renders radio buttons with correct labels', () => {
    wrapper = createComponent();
    expect(findFormRadioButtons()).toHaveLength(3);
    expect(findFormRadioButtons().at(0).text()).toContain('On by default');
    expect(findFormRadioButtons().at(1).text()).toContain('Off by default');
    expect(findFormRadioButtons().at(2).text()).toContain('Always off');
  });

  describe('with GitLab.com', () => {
    it('displays correct subtitle', () => {
      wrapper = createComponent({ provide: { isSaaS: true } });
      expect(findFormGroup().attributes('labeldescription')).toContain(
        'Control whether GitLab can process your code and project data to provide context to AI-powered features.',
      );
    });

    it('renders radio buttons with correct descriptions', () => {
      wrapper = createComponent({ provide: { isSaaS: true } });
      expect(findRadioButtonDescriptions().at(0).text()).toContain(
        'Allow GitLab to process your code and project data for AI-powered features throughout this namespace. Your data will be sent to GitLab Duo for processing. Groups, subgroups, and projects can individually opt out if needed.',
      );
      expect(findRadioButtonDescriptions().at(1).text()).toContain(
        'Block GitLab from processing your code and project data for AI-powered features by default. Your data stays private unless subgroups or projects individually opt in.',
      );
      expect(findRadioButtonDescriptions().at(2).text()).toContain(
        'Never allow GitLab to process your code and project data for AI-powered features. Your data will not be sent to GitLab Duo anywhere in this namespace.',
      );
    });
  });

  describe('with Self-Managed', () => {
    it('displays correct subtitle', () => {
      wrapper = createComponent({ provide: { isSaaS: false } });
      expect(findFormGroup().attributes('labeldescription')).toContain(
        'Control whether AI-powered features are available.',
      );
    });

    it('renders radio buttons with correct descriptions', () => {
      wrapper = createComponent({ provide: { isSaaS: false } });
      expect(findRadioButtonDescriptions().at(0).text()).toContain(
        'Features are available. However, any group, subgroup, or project can turn them off.',
      );
      expect(findRadioButtonDescriptions().at(1).text()).toContain(
        'Features are not available. However, any group, subgroup, or project can turn them on.',
      );
      expect(findRadioButtonDescriptions().at(2).text()).toContain(
        'Features are not available and cannot be turned on for any group, subgroup, or project.',
      );
    });
  });

  it('emits change event when radio button is selected', () => {
    wrapper = createComponent();
    findFormRadioButtons().at(1).vm.$emit('change');
    expect(findFormRadioButtons().at(1).attributes('value')).toBe(AVAILABILITY_OPTIONS.DEFAULT_OFF);
  });

  describe('when areDuoSettingsLocked is true', () => {
    beforeEach(() => {
      wrapper = createComponent({
        provide: {
          areDuoSettingsLocked: true,
        },
      });
    });

    it('disables radio buttons', () => {
      const radios = wrapper.findAllComponents(GlFormRadio);
      radios.wrappers.forEach((radio) => {
        expect(radio.attributes().disabled).toBe('true');
      });
    });

    it('shows CascadingLockIcon when cascadingSettingsData is provided', () => {
      expect(findCascadingLockIcon().exists()).toBe(true);
    });

    it('passes correct props to CascadingLockIcon', () => {
      expect(findCascadingLockIcon().props()).toMatchObject({
        isLockedByGroupAncestor: false,
        isLockedByApplicationSettings: false,
        ancestorNamespace: null,
      });
    });

    it('does not show CascadingLockIcon when cascadingSettingsData is empty', () => {
      wrapper = createComponent({
        provide: {
          cascadingSettingsData: {},
        },
      });
      expect(findCascadingLockIcon().exists()).toBe(false);
    });

    it('does not show CascadingLockIcon when cascadingSettingsData is null', () => {
      wrapper = createComponent({
        provide: {
          cascadingSettingsData: null,
        },
      });
      expect(findCascadingLockIcon().exists()).toBe(false);
    });
  });

  describe('when areDuoSettingsLocked is false', () => {
    it('does not show CascadingLockIcon', () => {
      wrapper = createComponent();
      expect(findCascadingLockIcon().exists()).toBe(false);
    });
  });
});
