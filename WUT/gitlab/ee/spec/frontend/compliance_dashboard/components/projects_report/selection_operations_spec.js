import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { mount, ErrorWrapper } from '@vue/test-utils';
import { nextTick } from 'vue';
import { createComplianceFrameworksResponse } from 'ee_jest/compliance_dashboard/mock_data';
import { mapProjects } from 'ee/compliance_dashboard/graphql/mappers';
import { validFetchResponse as getComplianceFrameworksResponse } from 'ee_jest/groups/settings/compliance_frameworks/mock_data';
import SelectionOperations from 'ee/compliance_dashboard/components/projects_report/selection_operations.vue';
import FrameworkSelectionBox from 'ee/compliance_dashboard/components/projects_report/framework_selection_box.vue';

describe('SelectionOperations component', () => {
  let wrapper;

  const findByText = (Component, text) =>
    wrapper.findAllComponents(Component).wrappers.find((w) => w.text().match(text)) ??
    new ErrorWrapper();

  const findOperationDropdown = () =>
    findByText(GlCollapsibleListbox, SelectionOperations.i18n.dropdownActionPlaceholder);
  const findFrameworkSelectionDropdown = () => wrapper.findComponent(FrameworkSelectionBox);

  const findApplyButton = () => findByText(GlButton, /^Apply$/);
  const findRemoveButton = () => findByText(GlButton, /^Remove$/);

  const select = (glDropdown, value) => {
    glDropdown.vm.$emit(GlCollapsibleListbox.model.event, value);
    return nextTick();
  };

  const createComponent = (props) => {
    wrapper = mount(SelectionOperations, {
      propsData: {
        groupPath: 'group-path',
        ...props,
      },
      stubs: {
        FrameworkSelectionBox: true,
      },
    });
  };

  describe('when selection is empty', () => {
    beforeEach(() => {
      createComponent({ selection: [] });
    });

    it('operation dropdown is disabled', () => {
      expect(findOperationDropdown().props('disabled')).toBe(true);
    });

    it('framework selection dropdown is not available', () => {
      expect(findFrameworkSelectionDropdown().exists()).toBe(false);
    });

    it('displays correct text', () => {
      expect(wrapper.text()).toContain('0 selected');
    });
  });

  describe('when selection is provided', () => {
    const COUNT = 2;
    const complianceFrameworkResponse = createComplianceFrameworksResponse({ count: COUNT });
    const projects = mapProjects(complianceFrameworkResponse.data.group.projects.nodes);

    beforeEach(() => {
      createComponent({ selection: projects });
    });

    it('operation dropdown is enabled', () => {
      expect(findOperationDropdown().props('disabled')).toBe(false);
    });

    describe('when selecting remove operation', () => {
      beforeEach(() =>
        select(findOperationDropdown(), SelectionOperations.operations.REMOVE_OPERATION),
      );

      it('renders remove button disabled by default', () => {
        expect(findRemoveButton().exists()).toBe(true);
        expect(findRemoveButton().props('disabled')).toBe(true);
      });

      it('framework selection dropdown is available', () => {
        expect(findFrameworkSelectionDropdown().exists()).toBe(true);
      });

      describe('when selecting framework', () => {
        const SELECTED_FRAMEWORK =
          getComplianceFrameworksResponse.data.namespace.complianceFrameworks.nodes[0].id;

        beforeEach(() => select(findFrameworkSelectionDropdown(), [SELECTED_FRAMEWORK]));

        it('enables apply button when framework is selected', () => {
          expect(findRemoveButton().props('disabled')).toBe(false);
        });

        it('clicking remove button emits change event', async () => {
          await findRemoveButton().vm.$emit('click');
          const expectedOperations = [
            {
              projectId: projects[0].id,
              frameworkIds: [projects[0].complianceFrameworks?.[0]?.id],
              previousFrameworkIds: [projects[0].complianceFrameworks?.[0]?.id],
            },
            {
              projectId: projects[1].id,
              frameworkIds: [],
              previousFrameworkIds: [projects[1].complianceFrameworks?.[0]?.id],
            },
          ];

          expect(wrapper.emitted('change').at(-1)).toStrictEqual([expectedOperations]);
        });
      });
    });

    describe('when selecting apply operation', () => {
      beforeEach(() =>
        select(findOperationDropdown(), SelectionOperations.operations.APPLY_OPERATION),
      );

      it('renders apply button, disabled by default', () => {
        expect(findApplyButton().exists()).toBe(true);
        expect(findApplyButton().props('disabled')).toBe(true);
      });

      it('framework selection dropdown is available', () => {
        expect(findFrameworkSelectionDropdown().exists()).toBe(true);
      });

      describe('when selecting framework', () => {
        const SELECTED_FRAMEWORK =
          getComplianceFrameworksResponse.data.namespace.complianceFrameworks.nodes[1].id;

        beforeEach(() => select(findFrameworkSelectionDropdown(), [SELECTED_FRAMEWORK]));

        it('enables apply button when framework is selected', () => {
          expect(findApplyButton().props('disabled')).toBe(false);
        });

        it('clicking cancel button resets state', async () => {
          wrapper
            .findAllComponents(GlButton)
            .wrappers.find((w) => w.text() === 'Cancel')
            .vm.$emit('click');

          await nextTick();

          expect(findOperationDropdown().props(GlCollapsibleListbox.model.prop)).toBe(null);
          expect(findFrameworkSelectionDropdown().exists()).toBe(false);
          expect(findApplyButton().exists()).toBe(true);
          expect(findApplyButton().props('disabled')).toBe(true);
        });

        describe('when clicking apply button', () => {
          beforeEach(() => findApplyButton().vm.$emit('click'));

          it('emits change event', async () => {
            await nextTick();

            expect(wrapper.emitted('change').at(-1)).toStrictEqual([
              projects.map((p) => ({
                projectId: p.id,
                frameworkIds: [p.complianceFrameworks?.[0]?.id, SELECTED_FRAMEWORK],
                previousFrameworkIds: [p.complianceFrameworks?.[0]?.id],
              })),
            ]);
          });

          it('apply button resets to disabled state', async () => {
            await nextTick();

            expect(findApplyButton().exists()).toBe(true);
            expect(findApplyButton().props('disabled')).toBe(true);
          });
        });
      });
    });

    it('displays correct text', () => {
      expect(wrapper.text()).toContain(`${COUNT} selected`);
    });

    it('re-emits create from framework selection box', async () => {
      select(findOperationDropdown(), SelectionOperations.operations.APPLY_OPERATION);

      await nextTick();

      findFrameworkSelectionDropdown().vm.$emit('create');

      expect(wrapper.emitted('create')).toHaveLength(1);
    });

    it('correctly updates selected framework when defaultFramework prop is updated', async () => {
      const NEW_FRAMEWORK_ID = 'new-framework-id';

      select(findOperationDropdown(), SelectionOperations.operations.APPLY_OPERATION);
      await nextTick();

      await wrapper.setProps({ defaultFramework: { id: NEW_FRAMEWORK_ID } });
      await nextTick();

      expect(findFrameworkSelectionDropdown().props('selected')).toEqual([NEW_FRAMEWORK_ID]);
    });
  });
});
