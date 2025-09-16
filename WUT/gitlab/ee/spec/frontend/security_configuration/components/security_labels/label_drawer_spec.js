import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LabelDrawer from 'ee/security_configuration/components/security_labels/label_drawer.vue';
import SecurityLabelForm from 'ee/security_configuration/components/security_labels/label_form.vue';
import LabelDeleteModal from 'ee/security_configuration/components/security_labels/label_delete_modal.vue';
import { DRAWER_MODES } from 'ee/security_configuration/components/security_labels/constants';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';

describe('LabelDrawer', () => {
  let wrapper;

  const label = { name: 'Label 1', color: '#fff', description: 'A label' };

  const createComponent = () => {
    wrapper = shallowMountExtended(LabelDrawer, {
      stubs: {
        GlDrawer,
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findForm = () => wrapper.findComponent(SecurityLabelForm);
  const findDeleteModal = () => wrapper.findComponent(LabelDeleteModal);
  const findSubmitButton = () => wrapper.findByTestId('submit-btn');
  const findCancelButton = () => wrapper.findByTestId('cancel-btn');
  const findDeleteButton = () => wrapper.findByTestId('delete-btn');

  beforeEach(() => {
    createComponent();
    wrapper.vm.open(DRAWER_MODES.ADD, label);
  });

  it('renders GlDrawer open with correct props', () => {
    expect(findDrawer().exists()).toBe(true);
    expect(findDrawer().props()).toMatchObject({
      open: true,
      zIndex: DRAWER_Z_INDEX,
    });
  });

  it('renders LabelForm with correct props', () => {
    expect(findForm().props()).toMatchObject({
      label,
      mode: DRAWER_MODES.ADD,
    });
  });

  it('renders LabelDeleteModal with correct visibility and label', () => {
    expect(findDeleteModal().props()).toMatchObject({
      visible: false,
      label,
    });
  });

  it('renders submit and cancel buttons', () => {
    expect(findSubmitButton().exists()).toBe(true);
    expect(findCancelButton().exists()).toBe(true);
  });

  it('does not render delete button in ADD mode', () => {
    expect(findDeleteButton().exists()).toBe(false);
  });
});
