import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DuoExpandedLoggingForm from 'ee/ai/settings/components/duo_expanded_logging_form.vue';

describe('DuoExpandedLoggingForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, injectedProps = {} } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(DuoExpandedLoggingForm, {
        provide: {
          ...injectedProps,
        },
        propsData: {
          ...props,
        },
        stubs: {
          GlFormCheckbox,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ injectedProps: { enabledExpandedLogging: true } });
  });

  const findTitle = () => wrapper.find('h5').text();
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findCheckboxLabel = () => wrapper.findByTestId('ai-logging-checkbox');

  it('has the correct title', () => {
    expect(findTitle()).toBe('Enable AI logs');
  });

  it('has the correct label', () => {
    expect(findCheckboxLabel().text()).toBe(
      'Capture detailed information about AI-related activities and requests.',
    );
  });

  describe('when expanded AI logs have been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { enabledExpandedLogging: true } });
    });

    it('renders the checkbox checked', () => {
      expect(findCheckbox().attributes('checked')).toBeDefined();
    });
  });

  describe('when expanded AI logs have not been enabled', () => {
    beforeEach(() => {
      createComponent({ injectedProps: { enabledExpandedLogging: false } });
    });

    it('renders the checkbox unchecked', () => {
      expect(findCheckbox().attributes('checked')).toBeUndefined();
    });
  });
});
