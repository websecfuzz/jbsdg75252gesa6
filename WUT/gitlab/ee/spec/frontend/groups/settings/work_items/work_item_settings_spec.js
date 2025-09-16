import { shallowMount } from '@vue/test-utils';
import CustomFieldsList from 'ee/groups/settings/work_items/custom_fields_list.vue';
import CustomStatusSettings from 'ee/groups/settings/work_items/custom_status_settings.vue';
import WorkItemSettings from 'ee/groups/settings/work_items/work_item_settings.vue';

describe('WorkItemSettings', () => {
  let wrapper;
  const fullPath = 'group/project';

  const createComponent = ({ workItemStatusFeatureFlag = false } = {}) => {
    wrapper = shallowMount(WorkItemSettings, {
      propsData: {
        fullPath,
      },
      provide: {
        glFeatures: {
          workItemStatusFeatureFlag,
        },
      },
    });
  };

  const findCustomFieldsList = () => wrapper.findComponent(CustomFieldsList);
  const findCustomStatusSettings = () => wrapper.findComponent(CustomStatusSettings);

  it('always renders CustomFieldsList component with correct props', () => {
    createComponent();

    expect(findCustomFieldsList().exists()).toBe(true);
    expect(findCustomFieldsList().props('fullPath')).toBe(fullPath);
  });

  describe('when workItemStatusFeatureFlag is disabled', () => {
    beforeEach(() => {
      createComponent({ workItemStatusFeatureFlag: false });
    });

    it('does not render CustomStatusSettings component', () => {
      expect(findCustomStatusSettings().exists()).toBe(false);
    });
  });

  describe('when workItemStatusFeatureFlag is enabled', () => {
    beforeEach(() => {
      createComponent({ workItemStatusFeatureFlag: true });
    });

    it('renders CustomStatusSettings component with correct props', () => {
      expect(findCustomStatusSettings().exists()).toBe(true);
    });
  });
});
