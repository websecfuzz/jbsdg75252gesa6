import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LabelDeleteModal from 'ee/security_configuration/components/security_labels/label_delete_modal.vue';

describe('LabelDeleteModal', () => {
  let wrapper;

  const label = { name: 'USA::Austin' };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(LabelDeleteModal, {
      propsData: {
        visible: true,
        label,
        ...props,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  it('renders the modal with the correct props and message', () => {
    createComponent();

    expect(findModal().props()).toMatchObject({
      modalId: 'delete-security-label-modal',
      title: 'Delete security label?',
      visible: true,
    });

    expect(findModal().text()).toBe(
      `Deleting the "${label.name}" Security Label will permanently remove it from its category and any projects where it is applied. This action cannot be undone.`,
    );
  });
});
