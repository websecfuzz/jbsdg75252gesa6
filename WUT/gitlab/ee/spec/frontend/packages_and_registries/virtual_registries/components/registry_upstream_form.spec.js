import { GlForm } from '@gitlab/ui';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('RegistryUpstreamForm', () => {
  let wrapper;

  const upstream = {
    id: 1,
    name: 'foo',
    url: 'https://example.com',
    description: 'bar',
    username: 'bax',
    cacheValidityHours: 12,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RegistryUpstreamForm, {
      propsData: props,
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findNameInput = () => wrapper.findByTestId('name-input');
  const findUpstreamUrlInput = () => wrapper.findByTestId('upstream-url-input');
  const findDescriptionInput = () => wrapper.findByTestId('description-input');
  const findUsernameInput = () => wrapper.findByTestId('username-input');
  const findPasswordInput = () => wrapper.findByTestId('password-input');
  const findCacheValidityHoursInput = () => wrapper.findByTestId('cache-validity-hours-input');
  const findSubmitButton = () => wrapper.findByTestId('submit-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findTestUpstreamButton = () => wrapper.findByTestId('test-upstream-button');

  beforeEach(() => {
    createComponent();
  });

  describe('renders', () => {
    it('renders Form', () => {
      expect(findForm().exists()).toBe(true);
    });

    describe('inputs', () => {
      it('renders Name input', () => {
        expect(findNameInput().exists()).toBe(true);
      });

      it('renders Upstream URL input', () => {
        expect(findUpstreamUrlInput().exists()).toBe(true);
      });

      it('renders Description input', () => {
        expect(findDescriptionInput().exists()).toBe(true);
      });

      it('renders Username input', () => {
        expect(findUsernameInput().exists()).toBe(true);
      });

      it('renders Password input', () => {
        expect(findPasswordInput().exists()).toBe(true);
      });

      it('renders Cache validity hours input', () => {
        expect(findCacheValidityHoursInput().props('value')).toBe(24);
      });
    });

    describe('inputs when upstream prop is set', () => {
      beforeEach(() => {
        createComponent({
          upstream,
        });
      });

      it('renders Name input', () => {
        expect(findNameInput().props('value')).toBe('foo');
      });

      it('renders Upstream URL input', () => {
        expect(findUpstreamUrlInput().props('value')).toBe('https://example.com');
      });

      it('renders Description input', () => {
        expect(findDescriptionInput().props('value')).toBe('bar');
      });

      it('renders Username input', () => {
        expect(findUsernameInput().props('value')).toBe('bax');
      });

      it('renders Password input', () => {
        expect(findPasswordInput().props('value')).toBe('');
      });

      it('renders Cache validity hours input', () => {
        expect(findCacheValidityHoursInput().props('value')).toBe(12);
      });
    });

    describe('buttons', () => {
      it('renders Create upstream button', () => {
        expect(findSubmitButton().text()).toBe('Create upstream');
      });

      it('renders Cancel button', () => {
        expect(findCancelButton().exists()).toBe(true);
      });

      it('renders Test upstream button if canTestUpstream is true', () => {
        createComponent({ canTestUpstream: true });
        expect(findTestUpstreamButton().exists()).toBe(true);
      });

      it('does not render Test upstream button if canTestUpstream is false', () => {
        createComponent({ canTestUpstream: false });
        expect(findTestUpstreamButton().exists()).toBe(false);
      });

      it('renders `Save changes` button when upstream exists', () => {
        createComponent({ upstream });
        expect(findSubmitButton().text()).toBe('Save changes');
      });
    });
  });

  describe('emits events', () => {
    it('emits submit event when form is submitted and form is valid', () => {
      createComponent({ upstream });

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');
      const [eventParams] = submittedEvent[0];

      expect(Boolean(submittedEvent)).toBe(true);
      expect(eventParams).toEqual(
        expect.objectContaining({
          name: 'foo',
          url: 'https://example.com',
          description: 'bar',
          username: 'bax',
          cacheValidityHours: 12,
        }),
      );
    });

    it('does not emit a submit event when the form is not valid', () => {
      createComponent({ upstream: { ...upstream, url: 'ftp://hello' } });

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');

      expect(Boolean(submittedEvent)).toBe(false);
    });

    it('emits cancel event when Cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');
      expect(Boolean(wrapper.emitted('cancel'))).toBe(true);
      expect(wrapper.emitted('cancel')[0]).toEqual([]);
    });

    it('emits testUpstream event when Test upstream button is clicked', () => {
      createComponent({ upstream, canTestUpstream: true });

      findTestUpstreamButton().vm.$emit('click');

      const testEvent = wrapper.emitted('testUpstream');
      const [eventParams] = testEvent[0];

      expect(Boolean(testEvent)).toBe(true);
      expect(eventParams).toEqual(
        expect.objectContaining({
          name: 'foo',
          url: 'https://example.com',
          description: 'bar',
          username: 'bax',
          cacheValidityHours: 12,
        }),
      );
    });

    it('does not emit a testUpstream event when the form is not valid', () => {
      createComponent({ upstream: { ...upstream, url: 'ftp://hello' }, canTestUpstream: true });

      findTestUpstreamButton().vm.$emit('click');

      const testEvent = wrapper.emitted('testUpstream');

      expect(Boolean(testEvent)).toBe(false);
    });
  });
});
