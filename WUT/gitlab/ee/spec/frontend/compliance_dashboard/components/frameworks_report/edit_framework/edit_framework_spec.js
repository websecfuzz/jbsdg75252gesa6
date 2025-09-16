import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createWrapper } from '@vue/test-utils';
import { GlAlert, GlLoadingIcon, GlTooltip } from '@gitlab/ui';
import RequirementsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/requirements_section.vue';
import getComplianceFrameworkQuery from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/graphql/get_compliance_framework.query.graphql';
import * as Utils from 'ee/groups/settings/compliance_frameworks/utils';
import EditFramework from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/edit_framework.vue';
import BasicInformationSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/basic_information_section.vue';
import PoliciesSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/policies_section.vue';
import ProjectsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/projects_section.vue';
import DeleteModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/delete_modal.vue';
import createComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/create_compliance_framework.mutation.graphql';
import updateComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/update_compliance_framework.mutation.graphql';
import deleteComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/delete_compliance_framework.mutation.graphql';
import createRequirementMutation from 'ee/compliance_dashboard/graphql/mutations/create_compliance_requirement.mutation.graphql';
import updateRequirementMutation from 'ee/compliance_dashboard/graphql/mutations/update_compliance_requirement.mutation.graphql';
import deleteRequirementMutation from 'ee/compliance_dashboard/graphql/mutations/delete_compliance_requirement.mutation.graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  mountExtended,
  shallowMountExtended,
  extendedWrapper,
} from 'helpers/vue_test_utils_helper';
import { ROUTE_FRAMEWORKS } from 'ee/compliance_dashboard/constants';
import { requirementEvents } from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

import {
  createComplianceFrameworksReportResponse,
  createComplianceFrameworkMutationResponse,
  mockRequirements,
  createFrameworkResponseWithEmptyPolicies,
  createFrameworkResponseWithPolicy,
} from '../../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility');
jest.mock('~/sentry/sentry_browser_wrapper');

const showToastMock = jest.fn();
const $toast = {
  show: showToastMock,
};

describe('Edit Framework Form', () => {
  let wrapper;
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const adherenceV2Enabled = true;
  const propsData = {
    id: '1',
  };
  const provideData = {
    groupPath: 'group-1',
    pipelineConfigurationFullPathEnabled: true,
    pipelineConfigurationEnabled: true,
    disableScanPolicyUpdate: false,
    featureSecurityPoliciesEnabled: true,
    migratePipelineToPolicyPath: '/migratepipelinetopolicypath',
    pipelineExecutionPolicyPath: '/policypath',
    adherenceV2Enabled,
  };
  const requirementsData = [
    {
      name: 'SOC2',
      description: 'Controls for SOC2',
      complianceRequirementsControls: {
        nodes: [],
      },
    },
    {
      name: 'GitLab',
      description: 'Controls used by GitLab',
      complianceRequirementsControls: {
        nodes: [],
      },
    },
    {
      name: 'External',
      description: 'Requirement with external control',
      complianceRequirementsControls: {
        nodes: [],
      },
    },
  ];

  const showDeleteModal = jest.fn();
  const routerBack = jest.fn();
  const interjectModal = jest.fn();
  const routerPush = jest.fn();

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findError = () => wrapper.findComponent(GlAlert);
  const findCancelButton = () => wrapper.findByTestId('cancel-btn');
  const findDeleteButton = () => wrapper.findByTestId('delete-btn');
  const findDeleteModal = () => wrapper.findComponent(DeleteModal);
  const findDeleteButtonTooltip = () => wrapper.findComponent(GlTooltip);
  const findPipelineInput = () => wrapper.findComponentByTestId('pipeline-configuration-input');
  const findRequirementsSection = () => wrapper.findComponent(RequirementsSection);
  const findPipelineMigrationPopup = () =>
    extendedWrapper(createWrapper(document.body)).find('[data-testid="pipeline-migration-popup"]');
  const findNameInput = () => wrapper.findByLabelText('Name');
  const findDescriptionInput = () => wrapper.findByLabelText('Description');
  const findColorInput = () => wrapper.find('input[type="color"]');

  const invalidFeedback = (input) =>
    input.closest('[role=group]').querySelector('.invalid-feedback')?.textContent ?? '';

  let hideMock;
  const clickToastAction = () => {
    const [[, toastOptions]] = showToastMock.mock.calls;
    hideMock = jest.fn();
    toastOptions.action.onClick(null, { hide: hideMock });
  };

  function createComponent(
    mountFn = mountExtended,
    { requestHandlers = [], routeParams = { id: '1' }, provide = {} } = {},
  ) {
    return mountFn(EditFramework, {
      apolloProvider: createMockApollo(requestHandlers),
      provide: {
        ...provideData,
        ...provide,
      },
      propsData,
      stubs: {
        PoliciesSection: true,
        ProjectsSection: true,
        DeleteModal: stubComponent(DeleteModal, {
          template: '<div></div>',
          methods: { show: showDeleteModal },
        }),
      },
      mocks: {
        $route: {
          params: routeParams,
        },
        $toast,
        $router: {
          back: routerBack,
          push: routerPush,
        },
      },
    });
  }

  const submitForm = async () => {
    const form = wrapper.find('form');
    await form.trigger('submit');
  };

  const fillAndSubmitForm = async (formData = {}) => {
    const defaultData = {
      name: 'Test Framework',
      description: 'Test Description',
      color: '#FF0000',
    };
    const data = { ...defaultData, ...formData };

    await findNameInput().setValue(data.name);
    await findDescriptionInput().setValue(data.description);
    await findColorInput().setValue(data.color);

    if (data.pipelineConfigurationFullPath) {
      const pipelineInput = wrapper.findByTestId('pipeline-configuration-input');
      await pipelineInput.setValue(data.pipelineConfigurationFullPath);
    }

    await nextTick();
    await submitForm();
  };

  beforeEach(() => {
    gon.suggested_label_colors = {
      '#000000': 'Black',
      '#0033CC': 'UA blue',
      '#428BCA': 'Moderate blue',
      '#44AD8E': 'Lime green',
    };
  });
  describe('Rendering', () => {
    it('renders the loading icon', () => {
      wrapper = createComponent(shallowMountExtended);
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('renders error if loading fails', async () => {
      wrapper = createComponent(shallowMountExtended);

      await waitForPromises();
      expect(findError().exists()).toBe(true);
    });

    it('does not attempt to load framework if no id provided in url', async () => {
      const queryFn = jest.fn();
      wrapper = createComponent(shallowMountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, queryFn]],
        routeParams: {},
      });

      await waitForPromises();
      expect(queryFn).not.toHaveBeenCalled();
    });

    it('loads framework if id provided in url', async () => {
      wrapper = createComponent(mountExtended, {
        requestHandlers: [
          [
            getComplianceFrameworkQuery,
            () => ({ ...createComplianceFrameworksReportResponse(), default: true }),
          ],
        ],
      });

      await waitForPromises();
      const values = Object.fromEntries(new FormData(wrapper.find('form').element));

      expect(values).toStrictEqual({
        name: "Auditor's framework 1",
        description: 'This is a framework 1',
        pipeline_configuration_full_path: '',
        // JSDOM issue, checking manually:
        // default: true,
      });

      expect(wrapper.find('input[name="default"]').attributes('value')).toBe('true');
    });

    it('navigates to compliance center if cancel button is clicked', async () => {
      wrapper = createComponent(mountExtended, {
        requestHandlers: [
          [
            getComplianceFrameworkQuery,
            () => ({ ...createComplianceFrameworksReportResponse(), default: true }),
          ],
        ],
      });

      await waitForPromises();

      findCancelButton().vm.$emit('click');

      expect(routerPush).toHaveBeenCalledWith({ name: ROUTE_FRAMEWORKS, query: { id: 1 } });
    });
  });

  describe('Security policies migration', () => {
    describe('popup when saving framework', () => {
      beforeEach(() => {
        wrapper = createComponent();
      });

      it('does not show popup without pipeline', async () => {
        await waitForPromises();
        const form = wrapper.find('form');
        await form.trigger('submit');
        await waitForPromises();

        expect(findPipelineMigrationPopup().exists()).toBe(false);
      });

      describe('with new framework', () => {
        it('does not show popup after pipeline', async () => {
          jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(true);

          const pipelineInput = findPipelineInput();
          await pipelineInput.setValue('.compliance.yml@flightjs/flight');
          await waitForPromises();

          await submitForm();
          await waitForPromises();

          expect(findPipelineMigrationPopup().exists()).toBe(false);
        });
      });
      describe('on update', () => {
        beforeEach(async () => {
          jest.runAllTimers();
          const mockResponse = (mutationType, namespace) =>
            jest
              .fn()
              .mockResolvedValue(
                createComplianceFrameworkMutationResponse(mutationType, namespace),
              );
          wrapper = await createComponent(mountExtended, {
            requestHandlers: [
              [getComplianceFrameworkQuery],
              [
                updateComplianceFrameworkMutation,
                mockResponse('updateComplianceFramework', 'complianceFramework'),
              ],
            ],
            routeParams: { id: 1 },
          });
        });
        it('shows popup after, with pipeline', async () => {
          jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(true);

          const pipelineInput = findPipelineInput();
          await pipelineInput.setValue('.compliance.yml@flightjs/flight');
          await waitForPromises();
          await fillAndSubmitForm();
          await waitForPromises();

          const { display, visibility, opacity } = window.getComputedStyle(
            findPipelineMigrationPopup().element,
          );
          expect(display).not.toEqual('none');
          expect(visibility).not.toEqual('hidden');
          expect(opacity).not.toEqual('0');

          expect(findPipelineMigrationPopup().exists()).toBe(true);
        });
        it('no popup after without pipeline', async () => {
          jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(true);

          await submitForm();
          await waitForPromises();
          expect(findPipelineMigrationPopup().exists()).toBe(false);
        });
      });
    });

    it('passes hasMigratedPipeline prop to BasicInformationSection if relevant policy exists', async () => {
      wrapper = createComponent(mountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, createComplianceFrameworksReportResponse]],
        routeParams: { id: 1 },
      });

      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('hasMigratedPipeline')).toBe(
        true,
      );
    });

    it('does not pass hasMigratedPipeline prop to BasicInformationSection if relevant policy does not exists', async () => {
      wrapper = createComponent(mountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, createComplianceFrameworksReportResponse]],
        routeParams: { id: 2 },
      });

      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('hasMigratedPipeline')).toBe(
        false,
      );
    });
  });

  describe('Validation', () => {
    beforeEach(async () => {
      wrapper = createComponent();
      await waitForPromises();
    });

    it('does not show validation feedback initially', () => {
      expect(findNameInput().attributes('state')).toBe(undefined);
      expect(findDescriptionInput().attributes('state')).toBe(undefined);
    });

    it('validates required fields after form submission', async () => {
      await fillAndSubmitForm({ name: '', description: '' });

      await submitForm();
      await nextTick();

      expect(invalidFeedback(findNameInput().element)).toContain('is required');
      expect(invalidFeedback(findDescriptionInput().element)).toContain('is required');
    });

    it('validates length of name field after form submission', async () => {
      await fillAndSubmitForm({ name: 'a'.repeat(256) });

      await submitForm();
      await nextTick();

      expect(invalidFeedback(findNameInput().element)).toContain('less than 255');
    });

    it.each`
      pipelineConfigurationFullPath | message
      ${'foo.yml@bar/baz'}          | ${'Configuration not found'}
      ${'foobar'}                   | ${'Invalid format'}
    `(
      'validates pipeline configuration after form submission',
      async ({ pipelineConfigurationFullPath, message }) => {
        jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(false);

        await fillAndSubmitForm({ pipelineConfigurationFullPath });

        const form = wrapper.find('form');
        await form.trigger('submit');
        await nextTick();

        expect(invalidFeedback(findPipelineInput().element)).toBe(message);
      },
    );
  });

  it.each`
    routeParams    | mutation                             | successHandler
    ${{}}          | ${createComplianceFrameworkMutation} | ${routerPush}
    ${{ id: '1' }} | ${updateComplianceFrameworkMutation} | ${interjectModal}
  `('invokes correct mutation', async ({ routeParams, mutation, successHandler }) => {
    const mockResponse = (mutationType, namespace) =>
      jest
        .fn()
        .mockResolvedValue(createComplianceFrameworkMutationResponse(mutationType, namespace));
    const stubHandlers = [
      [createComplianceFrameworkMutation, mockResponse('createComplianceFramework', 'framework')],
      [
        updateComplianceFrameworkMutation,
        mockResponse('updateComplianceFramework', 'complianceFramework'),
      ],
    ];

    wrapper = createComponent(mountExtended, {
      requestHandlers: [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        ...stubHandlers,
      ],
      routeParams,
    });
    await waitForPromises();

    await fillAndSubmitForm();
    await waitForPromises();
    expect(stubHandlers.find((handler) => handler[0] === mutation)[1]).toHaveBeenCalled();

    // we only redirect for new frameworks now
    if (successHandler === routerPush) {
      expect(successHandler).toHaveBeenCalled();
    }
  });

  it('tracks event of compliance framework creation', async () => {
    const response = createComplianceFrameworkMutationResponse(
      'createComplianceFramework',
      'framework',
    );

    wrapper = createComponent(mountExtended, {
      requestHandlers: [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        [createComplianceFrameworkMutation, jest.fn().mockResolvedValue(response)],
      ],
      routeParams: {},
    });
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    await waitForPromises();

    await fillAndSubmitForm();
    await waitForPromises();
    expect(trackEventSpy).toHaveBeenCalledWith(
      'create_compliance_framework',
      {
        property: response.data.createComplianceFramework.framework.id,
      },
      undefined,
    );
  });

  describe('Creating requirements', () => {
    let createRequirementMutationMock;
    let createFrameworkMutationMock;
    const mockFrameworkId = 'gid://gitlab/ComplianceManagement::Framework/1';

    beforeEach(() => {
      createRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          createComplianceRequirement: {
            requirement: {
              id: 'gid://gitlab/ComplianceManagement::Requirement/2',
              name: 'GitLab',
              description: 'Controls used by GitLab',
              __typename: 'ComplianceManagement::Requirement',
              complianceRequirementsControls: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/1',
                    name: 'minimum_approvals_required',
                    controlType: 'internal',
                    expression: {
                      __typename: 'IntegerExpression',
                      field: 'minimum_approvals_required',
                      operator: '=',
                      value: 1,
                    },
                    externalControlName: null,
                    externalUrl: null,
                  },
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/2',
                    name: 'scanner_sast_running',
                    controlType: 'internal',
                    expression: {
                      __typename: 'BooleanExpression',
                      field: 'scanner_sast_running',
                      operator: '=',
                      value: true,
                    },
                    externalControlName: null,
                    externalUrl: null,
                  },
                ],
              },
            },
            errors: [],
          },
        },
      });

      createFrameworkMutationMock = jest
        .fn()
        .mockResolvedValue(
          createComplianceFrameworkMutationResponse('createComplianceFramework', 'framework'),
        );
    });

    it('stores requirementsData locally when adding to a new framework and creates them after the framework is created', async () => {
      const stubHandlers = [
        [createComplianceFrameworkMutation, createFrameworkMutationMock],
        [createRequirementMutation, createRequirementMutationMock],
      ];

      wrapper = createComponent(mountExtended, {
        requestHandlers: [
          [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
          ...stubHandlers,
        ],
        routeParams: {},
        provide: {
          adherenceV2Enabled: true,
        },
      });
      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);

      requirementsData.forEach((requirement, index) => {
        requirementsSection.vm.$emit(requirementEvents.create, { requirement, index });
      });

      expect(wrapper.vm.requirements).toEqual(requirementsData);
      expect(createRequirementMutationMock).not.toHaveBeenCalled();

      await fillAndSubmitForm();
      await waitForPromises();

      expect(createFrameworkMutationMock).toHaveBeenCalledTimes(1);
      expect(createRequirementMutationMock).toHaveBeenCalledTimes(requirementsData.length);

      mockRequirements.forEach((requirement) => {
        expect(createRequirementMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            input: {
              complianceFrameworkId: mockFrameworkId,
              params: {
                name: requirement.name,
                description: requirement.description,
              },
              controls: [],
            },
          }),
        );
      });
    });

    it('immediately calls create requirement mutation when adding a requirement to an existing framework', async () => {
      const stubHandlers = [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        [createRequirementMutation, createRequirementMutationMock],
      ];

      wrapper = createComponent(mountExtended, {
        requestHandlers: stubHandlers,
        routeParams: { id: '1' },
        provide: {
          adherenceV2Enabled: true,
        },
      });
      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);

      requirementsData.forEach((requirement, index) => {
        requirementsSection.vm.$emit(requirementEvents.create, { requirement, index });
      });

      await waitForPromises();

      expect(createRequirementMutationMock).toHaveBeenCalledTimes(requirementsData.length);

      requirementsData.forEach((requirement) => {
        expect(createRequirementMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            input: {
              complianceFrameworkId: mockFrameworkId,
              params: {
                name: requirement.name,
                description: requirement.description,
              },
              controls: [],
            },
          }),
        );
      });
    });

    it('handles errors during immediate requirement creation for existing frameworks', async () => {
      const errorMessage = 'An error occurred';
      createRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          createComplianceRequirement: {
            requirement: null,
            errors: [errorMessage],
          },
        },
      });

      const stubHandlers = [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        [createRequirementMutation, createRequirementMutationMock],
      ];

      wrapper = createComponent(mountExtended, {
        requestHandlers: stubHandlers,
        routeParams: { id: '1' },
        provide: {
          adherenceV2Enabled: true,
        },
      });
      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);

      requirementsSection.vm.$emit(requirementEvents.create, {
        requirement: requirementsData[0],
        index: 0,
      });
      await waitForPromises();

      expect(createRequirementMutationMock).toHaveBeenCalledTimes(1);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('Updating requirements', () => {
    let updateRequirementMutationMock;

    beforeEach(() => {
      updateRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          updateComplianceRequirement: {
            requirement: {
              id: 'gid://gitlab/ComplianceManagement::Requirement/1',
              name: 'SOC2 Updated',
              description: 'Updated Controls for SOC2',
              __typename: 'ComplianceManagement::Requirement',
            },
            errors: [],
          },
        },
      });
    });

    it('updates requirement with controlExpression when editing an existing framework', async () => {
      const stubHandlers = [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        [updateRequirementMutation, updateRequirementMutationMock],
      ];

      wrapper = createComponent(mountExtended, {
        requestHandlers: stubHandlers,
        routeParams: { id: '1' },
        provide: {
          adherenceV2Enabled: true,
        },
      });

      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);

      const updatedRequirement = {
        id: 'gid://gitlab/ComplianceManagement::Requirement/1',
        name: 'SOC2 Updated',
        description: 'Updated Controls for SOC2',
        complianceRequirementsControls: {
          nodes: [],
        },
      };

      requirementsSection.vm.$emit(requirementEvents.update, { requirement: updatedRequirement });

      await waitForPromises();

      expect(updateRequirementMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            id: updatedRequirement.id,
            params: {
              name: updatedRequirement.name,
              description: updatedRequirement.description,
            },
            controls: [],
          },
        }),
      );
    });

    it('handles errors during requirement update', async () => {
      const errorMessage = 'An error occurred';
      updateRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          updateComplianceRequirement: {
            requirement: null,
            errors: [errorMessage],
          },
        },
      });

      const stubHandlers = [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        [updateRequirementMutation, updateRequirementMutationMock],
      ];

      wrapper = createComponent(mountExtended, {
        requestHandlers: stubHandlers,
        routeParams: { id: '1' },
        provide: {
          adherenceV2Enabled: true,
        },
      });

      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);

      const updatedRequirement = {
        id: 'gid://gitlab/ComplianceManagement::Requirement/1',
        name: 'SOC2 Updated',
        description: 'Updated Controls for SOC2',
      };

      requirementsSection.vm.$emit(requirementEvents.update, { requirement: updatedRequirement });

      await waitForPromises();

      expect(updateRequirementMutationMock).toHaveBeenCalled();

      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('preserves staged controls when editing a requirement multiple times', async () => {
      const initialRequirement = {
        id: 'gid://gitlab/ComplianceManagement::Requirement/1',
        name: 'SOC2',
        description: 'Controls for SOC2',
        complianceRequirementsControls: {
          nodes: [
            {
              id: 'gid://gitlab/ComplianceManagement::Control/1',
              name: 'minimum_approvals_required',
              controlType: 'internal',
              expression: {
                __typename: 'IntegerExpression',
                field: 'minimum_approvals_required',
                operator: '=',
                value: 1,
              },
              externalControlName: null,
              externalUrl: null,
            },
          ],
        },
      };

      updateRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          updateComplianceRequirement: {
            requirement: {
              id: 'gid://gitlab/ComplianceManagement::Requirement/1',
              name: 'SOC2 Updated',
              description: 'Updated Controls for SOC2',
              __typename: 'ComplianceManagement::Requirement',
              complianceRequirementsControls: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/1',
                    name: 'minimum_approvals_required',
                    controlType: 'internal',
                    expression: {
                      __typename: 'IntegerExpression',
                      field: 'minimum_approvals_required',
                      operator: '=',
                      value: 1,
                    },
                    externalControlName: null,
                    externalUrl: null,
                  },
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/2',
                    name: 'scanner_sast_running',
                    controlType: 'internal',
                    expression: {
                      __typename: 'BooleanExpression',
                      field: 'scanner_sast_running',
                      operator: '=',
                      value: true,
                    },
                    externalControlName: null,
                    externalUrl: null,
                  },
                ],
                __typename: 'ComplianceRequirementControlConnection',
              },
            },
            errors: [],
          },
        },
      });

      const mockFrameworkResponse = createComplianceFrameworksReportResponse();
      mockFrameworkResponse.data.namespace.complianceFrameworks.nodes[0].complianceRequirements = {
        nodes: [initialRequirement],
      };

      wrapper = createComponent(mountExtended, {
        requestHandlers: [
          [getComplianceFrameworkQuery, () => mockFrameworkResponse],
          [updateRequirementMutation, updateRequirementMutationMock],
        ],
        routeParams: { id: '1' },
        provide: {
          adherenceV2Enabled: true,
        },
      });

      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);

      const firstUpdateRequirement = {
        ...initialRequirement,
        name: 'SOC2 Updated',
        description: 'Updated Controls for SOC2',
        stagedControls: [
          {
            id: 'gid://gitlab/ComplianceManagement::Control/1',
            name: 'minimum_approvals_required',
            controlType: 'internal',
            expression: {
              __typename: 'IntegerExpression',
              field: 'minimum_approvals_required',
              operator: '=',
              value: 1,
            },
            externalControlName: null,
            externalUrl: null,
          },
          {
            id: 'gid://gitlab/ComplianceManagement::Control/2',
            name: 'scanner_sast_running',
            controlType: 'internal',
            expression: {
              __typename: 'BooleanExpression',
              field: 'scanner_sast_running',
              operator: '=',
              value: true,
            },
            externalControlName: null,
            externalUrl: null,
          },
        ],
      };

      requirementsSection.vm.$emit(requirementEvents.update, {
        requirement: firstUpdateRequirement,
        index: 0,
      });

      await waitForPromises();

      expect(updateRequirementMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            id: firstUpdateRequirement.id,
            params: {
              name: firstUpdateRequirement.name,
              description: firstUpdateRequirement.description,
            },
            controls: expect.arrayContaining([
              expect.objectContaining({
                name: 'minimum_approvals_required',
                controlType: 'internal',
              }),
              expect.objectContaining({
                name: 'scanner_sast_running',
                controlType: 'internal',
              }),
            ]),
          },
        }),
      );

      expect(wrapper.vm.requirements[0].complianceRequirementsControls.nodes).toHaveLength(2);

      const secondUpdateRequirement = {
        ...wrapper.vm.requirements[0],
        name: 'SOC2 Updated Again',
        description: 'Twice Updated Controls for SOC2',
      };

      updateRequirementMutationMock.mockClear();

      requirementsSection.vm.$emit(requirementEvents.update, {
        requirement: secondUpdateRequirement,
        index: 0,
      });

      await waitForPromises();

      expect(updateRequirementMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            id: secondUpdateRequirement.id,
            params: {
              name: secondUpdateRequirement.name,
              description: secondUpdateRequirement.description,
            },
            controls: expect.arrayContaining([
              expect.objectContaining({
                name: 'minimum_approvals_required',
                controlType: 'internal',
              }),
              expect.objectContaining({
                name: 'scanner_sast_running',
                controlType: 'internal',
              }),
            ]),
          },
        }),
      );
    });
  });

  describe('Deleting requirements', () => {
    let createRequirementMutationMock;
    let deleteRequirementMutationMock;

    beforeEach(() => {
      createRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          createComplianceRequirement: {
            requirement: {
              id: 'gid://gitlab/ComplianceManagement::Requirement/2',
              name: 'GitLab',
              description: 'Controls used by GitLab',
              __typename: 'ComplianceManagement::Requirement',
              complianceRequirementsControls: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/1',
                    name: 'minimum_approvals_required',
                    controlType: 'internal',
                    expression: {
                      __typename: 'IntegerExpression',
                      field: 'minimum_approvals_required',
                      operator: '=',
                      value: 1,
                    },
                    externalControlName: null,
                    externalUrl: null,
                  },
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/2',
                    name: 'scanner_sast_running',
                    controlType: 'internal',
                    expression: {
                      __typename: 'BooleanExpression',
                      field: 'scanner_sast_running',
                      operator: '=',
                      value: true,
                    },
                    externalControlName: null,
                    externalUrl: null,
                  },
                ],
              },
            },
            errors: [],
          },
        },
      });

      deleteRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          destroyComplianceRequirement: {
            errors: [],
          },
        },
      });
    });

    describe('deleting requirements when creating a new framework', () => {
      beforeEach(async () => {
        wrapper = createComponent(mountExtended, {
          requestHandlers: [],
          routeParams: {},
          provide: {
            adherenceV2Enabled: true,
          },
        });

        await waitForPromises();

        const requirementsSection = wrapper.findComponent(RequirementsSection);

        requirementsData.forEach((requirement, index) => {
          requirementsSection.vm.$emit(requirementEvents.create, { requirement, index });
        });

        await waitForPromises();
      });

      it('deletes and undoes delete of a requirement', async () => {
        const requirementsSection = wrapper.findComponent(RequirementsSection);

        requirementsSection.vm.$emit(requirementEvents.delete, 1);

        await nextTick();

        expect(requirementsSection.props('requirements')).toEqual([
          requirementsData[0],
          requirementsData[2],
        ]);

        clickToastAction();

        expect(hideMock).toHaveBeenCalledTimes(1);

        expect(requirementsSection.props('requirements')).toEqual(requirementsData);
      });
    });

    describe('deleting requirements when editing an existing framework', () => {
      beforeEach(async () => {
        const mockFrameworkResponse = createComplianceFrameworksReportResponse();
        mockFrameworkResponse.data.namespace.complianceFrameworks.nodes[0].complianceRequirements =
          {
            nodes: mockRequirements,
          };

        wrapper = createComponent(mountExtended, {
          requestHandlers: [
            [getComplianceFrameworkQuery, () => mockFrameworkResponse],
            [createRequirementMutation, createRequirementMutationMock],
            [deleteRequirementMutation, deleteRequirementMutationMock],
          ],
          routeParams: { id: '1' },
          provide: {
            adherenceV2Enabled: true,
          },
        });

        await waitForPromises();
      });

      it('deletes and undoes delete of a requirement', async () => {
        const requirementsSection = wrapper.findComponent(RequirementsSection);
        requirementsSection.vm.$emit(requirementEvents.delete, 1);

        await waitForPromises();

        expect(deleteRequirementMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            input: { id: mockRequirements[1].id },
          }),
        );

        expect(requirementsSection.props('requirements')).toEqual([
          mockRequirements[0],
          mockRequirements[2],
        ]);

        expect(showToastMock).toHaveBeenCalledTimes(1);

        clickToastAction();

        expect(hideMock).toHaveBeenCalledTimes(1);

        expect(createRequirementMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            input: {
              complianceFrameworkId: expect.any(String),
              params: {
                name: mockRequirements[1].name,
                description: mockRequirements[1].description,
              },
              controls: [
                {
                  controlType: 'internal',
                  expression: {
                    __typename: 'IntegerExpression',
                    field: 'minimum_approvals_required',
                    operator: '=',
                    value: 1,
                  },
                  externalControlName: '',
                  externalUrl: '',
                  name: 'minimum_approvals_required',
                },
                {
                  controlType: 'internal',
                  expression: {
                    __typename: 'BooleanExpression',
                    field: 'scanner_sast_running',
                    operator: '=',
                    value: true,
                  },
                  externalControlName: '',
                  externalUrl: '',
                  name: 'scanner_sast_running',
                },
              ],
            },
          }),
        );

        await waitForPromises();

        expect(requirementsSection.props('requirements')).toEqual(mockRequirements);
      });
    });
  });

  describe('Delete button', () => {
    it('does not render delete button if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();

      expect(findDeleteButton().exists()).toBe(false);
    });

    describe('when policy collections are empty', () => {
      beforeEach(async () => {
        const response = createFrameworkResponseWithEmptyPolicies();

        wrapper = createComponent(shallowMountExtended, {
          requestHandlers: [[getComplianceFrameworkQuery, () => response]],
        });

        await waitForPromises();
      });

      it('enables the delete button', () => {
        expect(findDeleteButton().props('disabled')).toBe(false);
      });

      it('does not render a tooltip', () => {
        expect(findDeleteButtonTooltip().exists()).toBe(false);
      });
    });

    describe.each([
      'scanResultPolicies',
      'pipelineExecutionPolicies',
      'scanExecutionPolicies',
      'vulnerabilityManagementPolicies',
    ])(`when %s collection has nodes`, (policyType) => {
      beforeEach(async () => {
        const response = createFrameworkResponseWithPolicy(policyType);

        wrapper = createComponent(shallowMountExtended, {
          requestHandlers: [[getComplianceFrameworkQuery, () => response]],
        });

        await waitForPromises();
      });

      it('disables the delete button', () => {
        expect(findDeleteButton().props('disabled')).toBe(true);
      });

      it('renders the correct tooltip message', () => {
        const tooltip = findDeleteButtonTooltip();
        expect(tooltip.exists()).toBe(true);
        expect(tooltip.attributes('title')).toBe(
          "Compliance frameworks that have a scoped policy can't be deleted",
        );
      });
    });

    it('disables the delete button and shows correct tooltip when framework is default', async () => {
      const response = createComplianceFrameworksReportResponse();
      response.data.namespace.complianceFrameworks.nodes[0].default = true;

      wrapper = createComponent(shallowMountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, () => response]],
      });

      await waitForPromises();

      const deleteButton = findDeleteButton();
      expect(deleteButton.props('disabled')).toBe(true);

      const tooltip = findDeleteButtonTooltip();
      expect(tooltip.exists()).toBe(true);
      expect(tooltip.attributes('title')).toBe("The default framework can't be deleted");
    });

    it('renders delete button if editing existing framework', async () => {
      wrapper = createComponent();
      await waitForPromises();

      expect(findDeleteButton().exists()).toBe(true);
    });

    it('clicking delete button invokes modal', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();

      findDeleteButton().vm.$emit('click');

      expect(showDeleteModal).toHaveBeenCalled();
    });

    describe('Deleteframework mutation', () => {
      let resolveDeleteFrameworkMutation;
      const deleteFrameworkMutationFn = jest.fn().mockImplementation(
        () =>
          new Promise((resolve) => {
            resolveDeleteFrameworkMutation = resolve;
          }),
      );
      beforeEach(async () => {
        wrapper = createComponent(shallowMountExtended, {
          requestHandlers: [
            [
              getComplianceFrameworkQuery,
              () => ({ ...createComplianceFrameworksReportResponse(), default: true }),
            ],
            [deleteComplianceFrameworkMutation, deleteFrameworkMutationFn],
          ],
        });
        await waitForPromises();

        findDeleteModal().vm.$emit('delete');
        await waitForPromises();
      });

      it('invokes delete process and navigates back on success removal', async () => {
        expect(deleteFrameworkMutationFn).toHaveBeenCalled();

        resolveDeleteFrameworkMutation({ data: { destroyComplianceFramework: { errors: [] } } });
        await waitForPromises();

        expect(routerBack).toHaveBeenCalled();
      });

      it('invokes delete process and displays alert when mutation failed', async () => {
        const errorMessage = 'something went wrong';

        expect(deleteFrameworkMutationFn).toHaveBeenCalled();

        resolveDeleteFrameworkMutation({
          data: { destroyComplianceFramework: { errors: [errorMessage] } },
        });
        await waitForPromises();

        expect(findError().text()).toBe(errorMessage);
      });
    });
  });

  describe('Basic information section', () => {
    it('renders basic information section as expanded if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('isExpanded')).toBe(true);
    });

    it('renders basic information section as not expanded when editing', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();
      expect(wrapper.findComponent(BasicInformationSection).props('isExpanded')).toBe(false);
    });
  });

  describe('Requirements section', () => {
    it('renders requirements section if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();
      expect(findRequirementsSection().exists()).toBe(true);
    });

    it('render requirements section if editing framework', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();
      expect(wrapper.findComponent(RequirementsSection).exists()).toBe(true);
    });

    it('does not render policies section if feature is disabled', async () => {
      wrapper = createComponent(shallowMountExtended, {
        provide: {
          adherenceV2Enabled: false,
        },
      });
      await waitForPromises();
      expect(wrapper.findComponent(RequirementsSection).exists()).toBe(false);
    });
  });

  describe('Policies section', () => {
    it('does not render policies section if creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();
      expect(wrapper.findComponent(PoliciesSection).exists()).toBe(false);
    });

    it('render policies section if editing framework', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();
      expect(wrapper.findComponent(PoliciesSection).exists()).toBe(true);
    });

    it('does not render policies section if feature is disabled', async () => {
      wrapper = createComponent(shallowMountExtended, {
        provide: {
          featureSecurityPoliciesEnabled: false,
        },
      });
      await waitForPromises();
      expect(wrapper.findComponent(PoliciesSection).exists()).toBe(false);
    });
  });

  describe('Projects section', () => {
    it('renders projects section when creating new framework', async () => {
      wrapper = createComponent(shallowMountExtended, { routeParams: {} });
      await waitForPromises();
      expect(wrapper.findComponent(ProjectsSection).exists()).toBe(true);
    });

    it('render projects section when editing framework', async () => {
      wrapper = createComponent(shallowMountExtended);
      await waitForPromises();
      expect(wrapper.findComponent(ProjectsSection).exists()).toBe(true);
    });
  });

  describe('Submit button', () => {
    beforeEach(async () => {
      wrapper = createComponent(mountExtended);
      await waitForPromises();
    });

    it('is enabled with empty form', () => {
      const submitButton = wrapper.findByTestId('submit-btn');
      expect(submitButton.props('disabled')).toBe(false);
    });

    it('remains enabled with invalid form data', async () => {
      await fillAndSubmitForm({ name: '' });

      const submitButton = wrapper.findByTestId('submit-btn');
      expect(submitButton.props('disabled')).toBe(false);
    });
  });

  describe('Creating requirements with external controls', () => {
    let createRequirementMutationMock;
    const mockFrameworkId = 'gid://gitlab/ComplianceManagement::Framework/1';

    beforeEach(() => {
      createRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          createComplianceRequirement: {
            requirement: {
              id: 'gid://gitlab/ComplianceManagement::Requirement/2',
              name: 'External Control Test',
              description: 'Test external controls',
              __typename: 'ComplianceManagement::Requirement',
              complianceRequirementsControls: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/3',
                    name: 'external_control',
                    controlType: 'external',
                    externalControlName: 'external_name',
                    externalUrl: 'https://example.com/control',
                    expression: null,
                  },
                ],
              },
            },
            errors: [],
          },
        },
      });
    });

    it('creates requirement with external control', async () => {
      const stubHandlers = [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        [createRequirementMutation, createRequirementMutationMock],
      ];

      wrapper = createComponent(mountExtended, {
        requestHandlers: stubHandlers,
        routeParams: { id: '1' },
        provide: {
          adherenceV2Enabled: true,
        },
      });
      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);
      const externalRequirement = {
        name: 'External Control Test',
        description: 'Test external controls',
        stagedControls: [
          {
            name: 'external_control',
            controlType: 'external',
            externalControlName: 'external_name',
            externalUrl: 'https://example.com/control',
          },
        ],
      };

      requirementsSection.vm.$emit(requirementEvents.create, { requirement: externalRequirement });
      await waitForPromises();

      expect(createRequirementMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            complianceFrameworkId: mockFrameworkId,
            params: {
              name: externalRequirement.name,
              description: externalRequirement.description,
            },
            controls: [
              {
                name: 'external_control',
                controlType: 'external',
                externalControlName: 'external_name',
                externalUrl: 'https://example.com/control',
                expression: '',
              },
            ],
          },
        }),
      );
    });
  });

  describe('Updating requirements with external controls', () => {
    let updateRequirementMutationMock;

    beforeEach(() => {
      updateRequirementMutationMock = jest.fn().mockResolvedValue({
        data: {
          updateComplianceRequirement: {
            requirement: {
              id: 'gid://gitlab/ComplianceManagement::Requirement/1',
              name: 'Updated External Control',
              description: 'Updated external control test',
              __typename: 'ComplianceManagement::Requirement',
              complianceRequirementsControls: {
                nodes: [
                  {
                    id: 'gid://gitlab/ComplianceManagement::Control/3',
                    name: 'updated_external_control',
                    controlType: 'external',
                    externalControlName: 'external_name_updated',
                    externalUrl: 'https://example.com/updated-control',
                    expression: null,
                  },
                ],
              },
            },
            errors: [],
          },
        },
      });
    });

    it('updates requirement with modified external control', async () => {
      const stubHandlers = [
        [getComplianceFrameworkQuery, createComplianceFrameworksReportResponse],
        [updateRequirementMutation, updateRequirementMutationMock],
      ];

      wrapper = createComponent(mountExtended, {
        requestHandlers: stubHandlers,
        routeParams: { id: '1' },
        provide: {
          adherenceV2Enabled: true,
        },
      });

      await waitForPromises();

      const requirementsSection = wrapper.findComponent(RequirementsSection);
      const updatedRequirement = {
        id: 'gid://gitlab/ComplianceManagement::Requirement/1',
        name: 'Updated External Control',
        description: 'Updated external control test',
        stagedControls: [
          {
            name: 'updated_external_control',
            controlType: 'external',
            externalControlName: 'external_name_updated',
            externalUrl: 'https://example.com/updated-control',
          },
        ],
      };

      requirementsSection.vm.$emit(requirementEvents.update, { requirement: updatedRequirement });
      await waitForPromises();

      expect(updateRequirementMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            id: updatedRequirement.id,
            params: {
              name: updatedRequirement.name,
              description: updatedRequirement.description,
            },
            controls: [
              {
                name: 'updated_external_control',
                controlType: 'external',
                externalControlName: 'external_name_updated',
                externalUrl: 'https://example.com/updated-control',
                expression: '',
              },
            ],
          },
        }),
      );
    });
  });

  describe('Requirements ordering', () => {
    it('sorts requirements by ID in ascending order', async () => {
      const unsortedRequirements = {
        nodes: [
          {
            id: 'gid://gitlab/ComplianceManagement::Requirement/3',
            name: 'Third',
            description: 'Third requirement',
            complianceRequirementsControls: {
              nodes: [],
            },
          },
          {
            id: 'gid://gitlab/ComplianceManagement::Requirement/1',
            name: 'First',
            description: 'First requirement',
            complianceRequirementsControls: {
              nodes: [],
            },
          },
          {
            id: 'gid://gitlab/ComplianceManagement::Requirement/2',
            name: 'Second',
            description: 'Second requirement',
            complianceRequirementsControls: {
              nodes: [],
            },
          },
        ],
      };

      const mockResponse = createComplianceFrameworksReportResponse();
      mockResponse.data.namespace.complianceFrameworks.nodes[0].complianceRequirements =
        unsortedRequirements;

      wrapper = createComponent(mountExtended, {
        requestHandlers: [[getComplianceFrameworkQuery, () => mockResponse]],
      });

      await waitForPromises();

      const sortedRequirements = wrapper.vm.requirements;
      expect(sortedRequirements.map((r) => r.name)).toEqual(['First', 'Second', 'Third']);
    });
  });
});
