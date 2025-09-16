import {
  GlTable,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlBadge,
  GlTooltip,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import RequirementsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirements_section.vue';
import RequirementModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirement_modal.vue';
import EditSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/edit_section.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  mockExternalControl,
  mockInternalControls,
  mockRequirements,
  mockGitLabStandardControls,
} from 'ee_jest/compliance_dashboard/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import controlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import {
  requirementEvents,
  emptyRequirement,
  maxRequirementsNumber,
} from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/constants';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('Requirements section', () => {
  let wrapper;

  const error = new Error('GraphQL error');

  let controlsQueryHandler;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findNewRequirementButton = () => wrapper.findByTestId('add-requirement-button');
  const findRequirementModal = () => wrapper.findComponent(RequirementModal);
  const findDeleteAction = () => wrapper.findByTestId('delete-action');
  const findEditAction = () => wrapper.findByTestId('edit-action');
  const findPagination = () => wrapper.findByTestId('requirements-pagination');

  const createComponent = async ({
    controlsQueryHandlerMockResponse = controlsQueryHandler,
    isNewFramework = true,
    requirements = mockRequirements,
  } = {}) => {
    const mockApollo = createMockApollo([[controlsQuery, controlsQueryHandlerMockResponse]]);

    wrapper = mountExtended(RequirementsSection, {
      propsData: {
        requirements,
        isNewFramework,
      },
      apolloProvider: mockApollo,
      stubs: { GlDisclosureDropdown, GlDisclosureDropdownItem },
    });

    await waitForPromises();
  };

  it('does not load requirements for existing framework on load', async () => {
    controlsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: mockGitLabStandardControls,
        },
      },
    });
    await createComponent({ isNewFramework: false });
    await waitForPromises();
    expect(controlsQueryHandler).not.toHaveBeenCalled();
  });

  describe('Rendering', () => {
    controlsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        complianceRequirementControls: {
          controlExpressions: mockGitLabStandardControls,
        },
      },
    });
    beforeEach(async () => {
      await createComponent();
    });

    it('Has title', () => {
      const title = wrapper.findByText('Requirements');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        'Configure requirements set forth by laws, regulations, and industry standards.',
      );
      expect(description.exists()).toBe(true);
    });

    it('passes correct items prop to a table', () => {
      const { items } = findTable().vm.$attrs;
      expect(items).toHaveLength(mockRequirements.length);
    });

    it('renders section as initially expanded if is-new-framework prop is true', () => {
      expect(wrapper.findComponent(EditSection).props('initiallyExpanded')).toBe(true);
    });

    it('renders section as collapsed if is-new-framework prop is false', async () => {
      await createComponent({ isNewFramework: false });
      expect(wrapper.findComponent(EditSection).props('initiallyExpanded')).toBe(false);
    });

    it.each`
      idx  | expectedRequirement    | expectedControls
      ${0} | ${mockRequirements[0]} | ${[]}
      ${1} | ${mockRequirements[1]} | ${mockInternalControls}
      ${2} | ${mockRequirements[2]} | ${[mockExternalControl]}
    `(
      'passes the correct items prop to the table at index $idx',
      async ({ idx, expectedRequirement, expectedControls }) => {
        await createComponent();
        const { items } = findTable().vm.$attrs;
        const item = items[idx];
        expect(item.name).toBe(expectedRequirement.name);
        expect(item.description).toBe(expectedRequirement.description);
        expect(item.controls).toMatchObject(expectedControls);
      },
    );

    it.each`
      idx  | name          | description                            | controls                                          | externalBadgeCount
      ${0} | ${'SOC2'}     | ${'Controls for SOC2'}                 | ${[]}                                             | ${0}
      ${1} | ${'GitLab'}   | ${'Controls used by GitLab'}           | ${['Minimum approvals required', 'SAST Running']} | ${0}
      ${2} | ${'External'} | ${'Requirement with external control'} | ${['external_name']}                              | ${1}
    `(
      'has the correct data for row $idx',
      ({ idx, name, description, controls, externalBadgeCount }) => {
        const frameworkRequirements = findTableRowData(idx);

        expect(frameworkRequirements.at(0).text()).toBe(name);
        expect(frameworkRequirements.at(1).text()).toBe(description);

        const listItems = frameworkRequirements
          .at(2)
          .findAll('li')
          .wrappers.map((w) =>
            w
              .text()
              .replace(/\s+External$/, '')
              .trim(),
          );
        expect(listItems).toEqual(controls);

        const badges = frameworkRequirements.at(2).findAllComponents(GlBadge);
        expect(badges).toHaveLength(externalBadgeCount);
      },
    );

    describe('Create requirement button', () => {
      beforeEach(() => {
        controlsQueryHandler = jest.fn().mockResolvedValue({
          data: {
            complianceRequirementControls: {
              controlExpressions: mockGitLabStandardControls,
            },
          },
        });
      });

      it('renders create requirement', () => {
        expect(findNewRequirementButton().text()).toBe('New requirement');
      });

      it('disables the add requirement button when maximum requirements limit is reached', async () => {
        const requirements = Array(maxRequirementsNumber).fill(mockRequirements[0]);
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isNewFramework: true,
          requirements,
        });

        expect(wrapper.vm.addingRequirementsDisabled).toBe(true);
        expect(findNewRequirementButton().props('disabled')).toBe(true);
      });

      it('shows a tooltip with max limit message when button is disabled', async () => {
        const requirements = Array(maxRequirementsNumber).fill(mockRequirements[0]);
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isNewFramework: true,
          requirements,
        });

        const tooltip = wrapper.findComponent(GlTooltip);
        expect(tooltip.exists()).toBe(true);
        expect(tooltip.attributes('title')).toBe(
          `You can create a maximum of ${maxRequirementsNumber} requirements`,
        );
      });

      it('enables the add requirement button when below maximum requirements limit', async () => {
        const requirements = Array(maxRequirementsNumber - 1).fill(mockRequirements[0]);
        await createComponent({
          controlsQueryHandlerMockResponse: controlsQueryHandler,
          isNewFramework: true,
          requirements,
        });

        expect(wrapper.vm.addingRequirementsDisabled).toBe(false);
        expect(findNewRequirementButton().props('disabled')).toBe(false);
      });

      it('does not show the tooltip when button is enabled', async () => {
        await createComponent({
          requirements: Array(maxRequirementsNumber - 1).fill(mockRequirements[0]),
          isNewFramework: true,
        });

        const tooltip = wrapper.findComponent(GlTooltip);
        expect(tooltip.exists()).toBe(false);
      });
    });
  });

  describe('Fetching data', () => {
    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockGitLabStandardControls,
          },
        },
      });
      createComponent();
    });

    it('calls the complianceRequirementControls query', () => {
      expect(controlsQueryHandler).toHaveBeenCalled();
    });

    it('updates data', async () => {
      await findNewRequirementButton().trigger('click');
      expect(findRequirementModal().props('gitlabStandardControls')).toMatchObject(
        mockGitLabStandardControls,
      );
    });
  });

  describe('Error handling', () => {
    beforeEach(async () => {
      controlsQueryHandler = jest.fn().mockRejectedValue(error);
      await createComponent({ controlsQueryHandler });
    });

    it('calls createAlert with the correct message on query error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error fetching compliance requirements controls data. Please refresh the page.',
        captureException: true,
        error,
      });
    });
  });

  describe('Creating requirement', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('passes correct props to requirement modal', async () => {
      await findNewRequirementButton().trigger('click');
      expect(findRequirementModal().props('requirement')).toMatchObject({
        ...emptyRequirement,
        index: null,
      });
    });

    it('emits a create event with the correct data when the requirement is created', async () => {
      await findNewRequirementButton().trigger('click');

      const newRequirement = {
        ...mockRequirements[0],
        name: 'New Requirement',
      };

      await findRequirementModal().vm.$emit(requirementEvents.create, {
        requirement: newRequirement,
        index: null,
      });
      expect(wrapper.emitted('create')).toEqual([[{ requirement: newRequirement, index: null }]]);
      expect(findRequirementModal().exists()).toBe(false);
    });
  });

  describe('Delete requirement', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('emits a delete event with the correct index when delete action is clicked', async () => {
      await findDeleteAction().vm.$emit('action');
      expect(wrapper.emitted(requirementEvents.delete)).toStrictEqual([[0]]);
    });
  });

  describe('Update requirement', () => {
    const index = 0;
    beforeEach(async () => {
      await createComponent();
    });

    it('passes correct props to requirement modal', async () => {
      await findEditAction().vm.$emit('action');
      expect(findRequirementModal().props('requirement')).toMatchObject({
        ...mockRequirements[index],
        index,
      });
    });

    it('emits an update event with the correct data when the requirement is updated', async () => {
      await findEditAction().vm.$emit('action');

      const updatedRequirement = {
        ...mockRequirements[index],
        name: 'Updated SOC2 Requirement',
      };

      await findRequirementModal().vm.$emit(requirementEvents.update, {
        requirement: updatedRequirement,
        index,
      });
      expect(wrapper.emitted('update')).toEqual([[{ requirement: updatedRequirement, index }]]);
      expect(findRequirementModal().exists()).toBe(false);
    });
  });

  describe('paginate requirements', () => {
    const generateRequirements = (count) => {
      return Array(count)
        .fill()
        .map((_, i) => ({ ...mockRequirements[0], name: `Requirement ${i + 1}` }));
    };

    beforeEach(() => {
      controlsQueryHandler = jest.fn().mockResolvedValue({
        data: {
          complianceRequirementControls: {
            controlExpressions: mockGitLabStandardControls,
          },
        },
      });
    });

    it('does not render pagination when there are fewer items than per-page limit', async () => {
      const fewRequirements = generateRequirements(10);
      await createComponent({ requirements: fewRequirements });
      expect(findPagination().exists()).toBe(false);
    });

    it('renders pagination when there are more items than per-page limit', async () => {
      const manyRequirements = generateRequirements(15);
      await createComponent({ requirements: manyRequirements });
      expect(findPagination().exists()).toBe(true);
    });

    it('passes correct props to pagination component', async () => {
      const manyRequirements = generateRequirements(25);
      await createComponent({ requirements: manyRequirements });

      expect(findPagination().props()).toMatchObject({
        value: 1,
        perPage: 10,
        totalItems: 25,
        align: 'center',
      });
    });

    it('updates currentPage when pagination is changed', async () => {
      const manyRequirements = generateRequirements(25);
      await createComponent({ requirements: manyRequirements });

      expect(wrapper.vm.currentPage).toBe(1);
      await findPagination().vm.$emit('input', 2);
      expect(wrapper.vm.currentPage).toBe(2);
    });
  });
});
