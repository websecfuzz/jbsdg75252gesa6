import {
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadio,
  GlBadge,
  GlLabel,
  GlButton,
  GlTableLite,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlLink,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CategoryForm from 'ee/security_configuration/components/security_labels/category_form.vue';
import {
  mockSecurityLabelCategories,
  mockSecurityLabels,
} from 'ee/security_configuration/graphql/resolvers';

const category = mockSecurityLabelCategories[0];

describe('Category form', () => {
  let wrapper;

  const createComponent = (props, mountFn = shallowMountExtended) => {
    wrapper = mountFn(CategoryForm, {
      propsData: {
        securityLabels: mockSecurityLabels,
        category,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlTableLite,
        GlDisclosureDropdown,
      },
    });
  };

  describe.each`
    description                  | id           | canEditCategory | canEditLabels | multipleSelection
    ${'locked category'}         | ${1}         | ${false}        | ${false}      | ${false}
    ${'limited edits category'}  | ${2}         | ${false}        | ${true}       | ${true}
    ${'fully editable category'} | ${3}         | ${true}         | ${true}       | ${true}
    ${'new category'}            | ${undefined} | ${true}         | ${true}       | ${false}
  `('$description', ({ id, canEditCategory, canEditLabels, multipleSelection }) => {
    describe('category metadata', () => {
      beforeEach(() => {
        createComponent({
          category: {
            ...category,
            id,
            canEditCategory,
            canEditLabels,
            multipleSelection,
          },
        });
      });

      describe('badge', () => {
        if (canEditCategory && canEditLabels) {
          it('is not shown', () => {
            expect(wrapper.findComponent(GlBadge).exists()).toBe(false);
          });
        }
        if (canEditCategory && !canEditLabels) {
          it('shows "limited edits allowed"', () => {
            expect(wrapper.findComponent(GlBadge).text()).toBe('Limited edits allowed');
          });
        }
        if (!canEditCategory && !canEditLabels) {
          it('shows "category locked"', () => {
            expect(wrapper.findComponent(GlBadge).text()).toBe('Category locked');
          });
        }
      });

      if (canEditCategory) {
        it('renders the category name and description form fields', () => {
          expect(wrapper.findComponent(GlFormInput).props('value')).toBe(category.name);
          expect(wrapper.findComponent(GlFormTextarea).props('value')).toBe(category.description);
        });
      } else {
        it('renders the category name and description as text', () => {
          expect(wrapper.findAllComponents(GlFormGroup).at(0).text()).toContain(category.name);
          expect(wrapper.findAllComponents(GlFormGroup).at(1).text()).toContain(
            category.description,
          );
        });
      }

      it('renders the selection type', () => {
        // if category is new
        if (id === undefined) {
          expect(wrapper.findAllComponents(GlFormRadio).at(0).text()).toBe('Single selection');
          expect(wrapper.findAllComponents(GlFormRadio).at(1).text()).toBe('Multiple selection');
        } else if (multipleSelection) {
          expect(wrapper.findComponent(GlFormRadio).exists()).toBe(false);
          expect(wrapper.findAllComponents(GlFormGroup).at(2).text()).toContain(
            'Multiple selection',
          );
        } else {
          expect(wrapper.findComponent(GlFormRadio).exists()).toBe(false);
          expect(wrapper.findAllComponents(GlFormGroup).at(2).text()).toContain('Single selection');
        }
      });
    });

    describe('labels', () => {
      beforeEach(() => {
        createComponent(
          {
            category: {
              ...category,
              id,
              canEditCategory,
              canEditLabels,
              multipleSelection,
            },
          },
          mountExtended,
        );
      });

      // if category is not new (empty)
      if (id !== undefined) {
        it('renders the labels in the category', () => {
          mockSecurityLabels
            .filter((label) => label.categoryId === category.id)
            .forEach((label, index) => {
              expect(wrapper.findAllComponents(GlLabel).at(index).props('title')).toBe(label.name);
              expect(
                wrapper.findComponent(GlTableLite).find('tbody').findAll('tr').at(index).text(),
              ).toContain(label.description);
              expect(wrapper.findAllComponents(GlLink).at(index).text()).toContain(
                `${label.projectCount} project`,
              );
            });
        });
      }

      if (canEditLabels) {
        it('shows a label create button that emits addLabel', async () => {
          wrapper.findComponent(GlButton).vm.$emit('click');
          await nextTick();

          expect(wrapper.emitted('addLabel')).toStrictEqual([[]]);
        });
      }
      if (canEditLabels && id !== undefined) {
        it('shows a label edit dropdown item that emits editLabel', async () => {
          wrapper.findAllComponents(GlDisclosureDropdownItem).at(0).vm.$emit('action');

          await nextTick();

          expect(wrapper.emitted()).toMatchObject({ editLabel: [[{ name: 'Asset Track' }]] });
        });
      }
      if (!canEditLabels) {
        it('does not show label create/edit actions', () => {
          expect(wrapper.findComponent(GlButton).exists()).toBe(false);
          expect(wrapper.findComponent(GlDisclosureDropdownItem).exists()).toBe(false);
        });
      }
    });
  });
});
