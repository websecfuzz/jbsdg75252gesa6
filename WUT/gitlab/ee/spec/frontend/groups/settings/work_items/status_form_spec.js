import { nextTick } from 'vue';
import { GlDisclosureDropdown, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InlineStatusForm from 'ee/groups/settings/work_items/status_form.vue';

describe('StatusForm', () => {
  let wrapper;

  const defaultProps = {
    categoryIcon: 'status-neutral',
    formData: {
      name: 'Test Status',
      color: '#ff0000',
      description: 'Test description',
    },
    formErrors: {
      name: '',
      color: '',
    },
  };

  const findColorDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findNameInput = () => wrapper.findByTestId('status-name-input');
  const findDescriptionInput = () => wrapper.findByTestId('status-description-input');
  const findAddDescriptionButton = () => wrapper.findByTestId('add-description-button');
  const findSaveButton = () => wrapper.findByTestId('save-status');
  const findUpdateButton = () => wrapper.findByTestId('update-status');
  const findCancelButton = () => wrapper.findByTestId('cancel-status');
  const findCategoryIcon = () => wrapper.findComponent(GlIcon);

  const createComponent = (props = {}) => {
    // Mock gon for suggested colors
    global.gon = {
      suggested_label_colors: {
        '#FF0000': 'Red',
        '#00FF00': 'Green',
        '#0000FF': 'Blue',
      },
    };

    wrapper = shallowMountExtended(InlineStatusForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('initial rendering', () => {
    beforeEach(async () => {
      createComponent({ isEditing: true });
      await nextTick();
    });

    it('displays category icon with correct color', () => {
      const icon = findCategoryIcon();
      expect(icon.props('name')).toBe('status-neutral');
      expect(icon.attributes('style')).toContain('color: rgb(255, 0, 0)');
    });

    it('displays name input with correct value', () => {
      expect(findNameInput().attributes('value')).toBe('Test Status');
    });

    it('displays color input with correct values', () => {
      const colorInput = wrapper.findByTestId('status-color-input');
      expect(colorInput.attributes('value')).toBe('#ff0000');
    });

    it('shows description field when description exists', () => {
      expect(findDescriptionInput().exists()).toBe(true);
      expect(findDescriptionInput().attributes('value')).toBe('Test description');
    });

    it('hides description field when no description', () => {
      createComponent({
        formData: {
          name: 'Test Status',
          color: '#ff0000',
          description: '',
        },
      });

      expect(findDescriptionInput().exists()).toBe(false);
      expect(findAddDescriptionButton().exists()).toBe(true);
    });
  });

  describe('form interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits update when name input changes', () => {
      findNameInput().vm.$emit('input', 'New Name');

      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...defaultProps.formData,
        name: 'New Name',
      });
    });

    it('emits update when color input changes', () => {
      const colorInputs = wrapper.findAllByTestId('status-color-input');
      colorInputs.at(0).vm.$emit('input', '#00ff00');

      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...defaultProps.formData,
        color: '#00ff00',
      });
    });

    it('emits update when description input changes', () => {
      findDescriptionInput().vm.$emit('input', 'New description');

      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...defaultProps.formData,
        description: 'New description',
      });
    });

    it('trims whitespace from color input', () => {
      const colorInputs = wrapper.findAllByTestId('status-color-input');
      colorInputs.at(0).vm.$emit('input', '  #00ff00  ');

      expect(wrapper.emitted('update')[0][0].color).toBe('#00ff00');
    });
  });

  describe('description field toggle', () => {
    beforeEach(() => {
      createComponent({
        formData: {
          name: 'Test Status',
          color: '#ff0000',
          description: '',
        },
      });
    });

    it('shows description field when add description button is clicked', async () => {
      expect(findDescriptionInput().exists()).toBe(false);

      findAddDescriptionButton().vm.$emit('click');
      await nextTick();

      expect(findDescriptionInput().exists()).toBe(true);
      expect(findAddDescriptionButton().exists()).toBe(false);
    });
  });

  describe('color dropdown', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays suggested colors in dropdown', () => {
      const dropdown = findColorDropdown();
      expect(dropdown.exists()).toBe(true);
    });
  });

  describe('save and cancel actions', () => {
    describe('when not editing', () => {
      beforeEach(() => {
        createComponent({ isEditing: false });
      });

      it('shows save button with correct text', () => {
        expect(findSaveButton().exists()).toBe(true);
        expect(findSaveButton().text()).toBe('Save');
        expect(findUpdateButton().exists()).toBe(false);
      });

      it('emits save event when save button is clicked', () => {
        findSaveButton().vm.$emit('click');
        expect(wrapper.emitted('save')).toHaveLength(1);
      });
    });

    describe('when editing', () => {
      beforeEach(() => {
        createComponent({ isEditing: true });
      });

      it('shows update button with correct text', () => {
        expect(findUpdateButton().exists()).toBe(true);
        expect(findUpdateButton().text()).toBe('Update');
        expect(findSaveButton().exists()).toBe(false);
      });

      it('emits save event when update button is clicked', () => {
        findUpdateButton().vm.$emit('click');
        expect(wrapper.emitted('save')).toHaveLength(1);
      });
    });

    it('emits cancel event when cancel button is clicked', () => {
      createComponent();
      findCancelButton().vm.$emit('click');
      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  it('limits name input to 32 characters', () => {
    createComponent();

    expect(findNameInput().attributes('maxlength')).toBe('32');
  });

  describe('color validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('triggers validate function on blur of color text input with invalid color', () => {
      const colorTextInput = wrapper.findByTestId('status-color-input-text');

      colorTextInput.vm.$emit('input', 'invalid-color');

      colorTextInput.vm.$emit('blur');

      expect(wrapper.emitted('validate')).toHaveLength(1);
    });
  });
});
