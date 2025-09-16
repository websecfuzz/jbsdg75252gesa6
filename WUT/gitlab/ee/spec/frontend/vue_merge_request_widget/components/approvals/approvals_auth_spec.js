import { GlModal } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import ApprovalsAuth from 'ee/vue_merge_request_widget/components/approvals/approvals_auth.vue';

const TEST_PASSWORD = 'password';

describe('Approval auth component', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(ApprovalsAuth, {
      propsData: {
        ...props,
        modalId: 'testid',
      },
      stubs: {
        GlModal: stubComponent(GlModal),
      },
    });
  };

  const findInput = () => wrapper.find('input[type=password]');
  const findErrorMessage = () => wrapper.findByText('Approval password is invalid.');

  describe('when created', () => {
    beforeEach(() => {
      createComponent();
    });

    it('password input control is rendered', () => {
      expect(findInput().exists()).toBe(true);
    });

    it('does not disable approve button', () => {
      expect(wrapper.findComponent(GlModal).props('actionPrimary')).toMatchObject({
        attributes: { loading: false },
      });
    });

    it('does not show error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });

    it('does not emit anything', () => {
      expect(wrapper.emitted()).toEqual({});
    });
  });

  describe('when approve clicked', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits the approve event', () => {
      findInput().setValue(TEST_PASSWORD);
      wrapper.findComponent(GlModal).vm.$emit('ok', { preventDefault: () => null });

      expect(wrapper.emitted().approve).toEqual([[TEST_PASSWORD]]);
    });
  });

  describe('when isApproving is true', () => {
    beforeEach(() => {
      createComponent({ isApproving: true });
    });

    it('disables the approve button', () => {
      expect(wrapper.findComponent(GlModal).props('actionPrimary')).toMatchObject({
        attributes: { loading: true },
      });
    });
  });

  describe('when hasError is true', () => {
    beforeEach(() => {
      createComponent({ hasError: true });
    });

    it('shows the invalid password message', () => {
      expect(findErrorMessage().exists()).toBe(true);
    });
  });
});
