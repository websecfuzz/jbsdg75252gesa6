import { GlBadge, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CategoryList from 'ee/security_configuration/components/security_labels/category_list.vue';
import { mockSecurityLabelCategories } from 'ee/security_configuration/graphql/resolvers';

const firstCategory = mockSecurityLabelCategories[0];
const secondCategory = mockSecurityLabelCategories[1];

describe('Category list', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(CategoryList, {
      propsData: {
        securityLabelCategories: mockSecurityLabelCategories,
        selectedCategory: firstCategory,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the category name, description, and labelled project count for each category', () => {
    expect(wrapper.text()).toContain(firstCategory.name);
    expect(wrapper.text()).toContain(firstCategory.description);
    expect(wrapper.findComponent(GlBadge).text()).toBe(firstCategory.labelCount.toString());
  });

  it('emits selectCategory on category click', () => {
    wrapper.findByTestId(`label-category-${secondCategory.id}`).trigger('click');

    expect(wrapper.emitted('selectCategory')[0][0]).toBe(secondCategory);
  });

  it('emits selectCategory with empty category on "Create category" click', () => {
    wrapper.findComponent(GlButton).vm.$emit('click');

    expect(wrapper.emitted('selectCategory')[0][0]).toStrictEqual({});
  });
});
