import { GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UnassignGroupModal from 'ee/admin/application_settings/security_and_compliance/components/unassign_modal.vue';

describe('UnassignGroupModal', () => {
  let wrapper;

  const defaultProps = {
    groupName: 'Test Group',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(UnassignGroupModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with correct props', () => {
      const modal = findModal();
      expect(modal.exists()).toBe(true);
      expect(modal.props('title')).toBe('Remove Test Group');
    });

    it('displays the modal text', () => {
      expect(wrapper.text()).toContain(
        'Selecting this will disconnect your top level compliance and security policy (CSP) group from all the other top level groups. All frameworks shared by the top level CSP group will also be disconnected due to this action.',
      );
      expect(wrapper.text()).toContain('Are you sure you want to remove Test Group as CSP group?');
    });

    it('generates correct modal title with group name', () => {
      createComponent({ groupName: 'My Custom Group' });
      expect(findModal().props('title')).toBe('Remove My Custom Group');
    });
  });
});
