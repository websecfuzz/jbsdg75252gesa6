import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import HeaderLockIcon from 'ee_component/repository/components/header_area/header_lock_icon.vue';

describe('HeaderLockIcon component', () => {
  let wrapper;

  const createComponent = ({ props = {}, provided = {} } = {}) => {
    wrapper = shallowMount(HeaderLockIcon, {
      provide: {
        glFeatures: {
          repositoryLockInformation: false,
        },
        ...provided,
      },
      propsData: {
        isTreeView: true,
        isLocked: false,
        ...props,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  beforeEach(() => {
    createComponent();
  });

  describe('when repositoryLockInformation feature flag is off', () => {
    it('does not render a button with a lock icon', () => {
      expect(findButton().exists()).toBe(false);
    });
  });

  describe('when repositoryLockInformation feature flag is on', () => {
    it('does not render a button with a lock icon', () => {
      createComponent({
        provided: { glFeatures: { repositoryLockInformation: true } },
      });

      expect(findButton().exists()).toBe(false);
    });

    describe('when a directory is locked', () => {
      beforeEach(() => {
        createComponent({
          provided: { glFeatures: { repositoryLockInformation: true } },
          props: { isLocked: true },
        });
      });

      it('renders a button with lock icon', () => {
        expect(findButton().exists()).toBe(true);
        expect(findButton().props('icon')).toBe('lock');
      });

      describe('tooltip text', () => {
        it('shows "Directory locked" tooltip', () => {
          expect(findButton().attributes('title')).toBe('Directory locked');
          expect(findButton().attributes('aria-label')).toBe('Directory locked');
        });

        it('shows tooltip with author information', () => {
          createComponent({
            provided: { glFeatures: { repositoryLockInformation: true } },
            props: { isLocked: true, lockAuthor: 'John Doe' },
          });

          expect(findButton().attributes('title')).toBe('Directory locked by John Doe');
        });
      });
    });

    describe('when a file is locked', () => {
      beforeEach(() => {
        createComponent({
          provided: { glFeatures: { repositoryLockInformation: true } },
          props: { isTreeView: false, isLocked: true },
        });
      });

      it('renders a button with lock icon', () => {
        expect(findButton().exists()).toBe(true);
        expect(findButton().props('icon')).toBe('lock');
      });

      describe('tooltip text', () => {
        it('shows "File locked" tooltip', () => {
          createComponent({
            provided: { glFeatures: { repositoryLockInformation: true } },
            props: { isTreeView: false, isLocked: true },
          });

          expect(findButton().attributes('title')).toBe('File locked');
          expect(findButton().attributes('aria-label')).toBe('File locked');
        });

        it('shows tooltip with author information', () => {
          createComponent({
            provided: { glFeatures: { repositoryLockInformation: true } },
            props: { isTreeView: false, isLocked: true, lockAuthor: 'John Doe' },
          });

          expect(findButton().attributes('title')).toBe('File locked by John Doe');
        });
      });
    });
  });
});
