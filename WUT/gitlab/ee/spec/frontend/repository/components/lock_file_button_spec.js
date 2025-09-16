import { GlButton, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';

import VueApollo from 'vue-apollo';
import LockFileButton from 'ee_component/repository/components/lock_file_button.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';

const DEFAULT_PROPS = {
  name: 'some_file.js',
  path: 'some/path',
  projectPath: 'some/project/path',
  isLocked: false,
  canLock: true,
};

describe('LockFileButton component', () => {
  let wrapper;

  const createMockApolloProvider = (resolverMock) => {
    Vue.use(VueApollo);
    return createMockApollo([[lockPathMutation, resolverMock]]);
  };

  const createComponent = (props = {}, lockMutation = jest.fn()) => {
    wrapper = shallowMount(LockFileButton, {
      apolloProvider: createMockApolloProvider(lockMutation),
      propsData: {
        ...DEFAULT_PROPS,
        ...props,
      },
    });
  };

  describe('lock button', () => {
    let lockMutationMock;
    const mockEvent = { preventDefault: jest.fn() };
    const findLockFileButton = () => wrapper.findComponent(GlButton);
    const findModal = () => wrapper.findComponent(GlModal);
    const clickSubmit = () => findModal().vm.$emit('primary', mockEvent);
    const clickHide = () => findModal().vm.$emit('hide', mockEvent);

    beforeEach(() => {
      lockMutationMock = jest.fn();
    });

    it('disables the lock button if canLock is set to false', () => {
      createComponent({ canLock: false });

      expect(findLockFileButton().props('disabled')).toBe(true);
    });

    it.each`
      isLocked | label
      ${false} | ${'Lock'}
      ${true}  | ${'Unlock'}
    `('renders the $label button label', ({ isLocked, label }) => {
      createComponent({ isLocked });

      expect(findLockFileButton().text()).toContain(label);
    });

    it('sets loading prop to true when LockFileButton was clicked', async () => {
      createComponent();
      findLockFileButton().vm.$emit('click');
      await clickSubmit();

      expect(findLockFileButton().props('loading')).toBe(true);
    });

    it('displays a confirm modal when the lock button is clicked', () => {
      createComponent();
      findLockFileButton().vm.$emit('click');
      expect(findModal().props('title')).toBe('Lock file?');
      expect(findModal().text()).toBe('Are you sure you want to lock some_file.js?');
      expect(findModal().props('actionPrimary').text).toBe('Lock');
    });

    it('displays a confirm modal when the unlock button is clicked', () => {
      createComponent({ isLocked: true });
      findLockFileButton().vm.$emit('click');
      expect(findModal().props('title')).toBe('Unlock file?');
      expect(findModal().text()).toBe('Are you sure you want to unlock some_file.js?');
      expect(findModal().props('actionPrimary').text).toBe('Unlock');
    });

    it('should hide the confirm modal when a hide action is triggered', async () => {
      createComponent();
      await findLockFileButton().vm.$emit('click');
      expect(findModal().props('visible')).toBe(true);

      await clickHide();
      expect(findModal().props('visible')).toBe(false);
    });

    it('executes a lock mutation once lock is confirmed', () => {
      lockMutationMock = jest.fn().mockRejectedValue('Test');
      createComponent({}, lockMutationMock);
      findLockFileButton().vm.$emit('click');
      clickSubmit();
      expect(lockMutationMock).toHaveBeenCalledWith({
        filePath: 'some/path',
        lock: true,
        projectPath: 'some/project/path',
      });
    });

    it('does not execute a lock mutation if lock not confirmed', () => {
      createComponent({}, lockMutationMock);
      findLockFileButton().vm.$emit('click');

      expect(lockMutationMock).not.toHaveBeenCalled();
    });
  });
});
