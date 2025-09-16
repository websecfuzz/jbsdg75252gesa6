import Vue from 'vue';
import VueRouter from 'vue-router';
import { GlAccordionItem } from '@gitlab/ui';
import * as Utils from 'ee/groups/settings/compliance_frameworks/utils';
import BasicInformationSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/basic_information_section.vue';
import EditSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/edit_section.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

describe('Basic information section', () => {
  Vue.use(VueRouter);
  let wrapper;
  const fakeFramework = {
    id: '1',
    name: 'Foo',
    description: 'Bar',
    pipelineConfigurationFullPath: null,
    color: null,
  };

  const defaultProvides = {
    migratePipelineToPolicyPath: '/migratepipelinetopolicypath',
    pipelineConfigurationFullPathEnabled: true,
    pipelineConfigurationEnabled: true,
    pipelineExecutionPolicyPath: '/policypath',
  };

  const invalidFeedback = (input) =>
    input.closest('[role=group].is-invalid')?.querySelector('.invalid-feedback').textContent ?? '';

  const router = new VueRouter();

  const createComponent = (props, provides) => {
    wrapper = mountExtended(BasicInformationSection, {
      provide: {
        ...defaultProvides,
        ...provides,
      },
      propsData: {
        value: fakeFramework,
        ...props,
      },
      stubs: {
        ColorPicker: true,
      },
      router,
    });
  };
  const findMaintenanceAlert = () => wrapper.findComponentByTestId('maintenance-mode-alert');
  const findMigrationActionButton = () => wrapper.findComponentByTestId('migrate-action-button');
  const findPipelineInput = () => wrapper.findComponentByTestId('pipeline-configuration-input');

  beforeEach(() => {
    createComponent();
  });

  it.each([['Name'], ['Description']])('has valid state initially', (fieldName) => {
    const input = wrapper.findByLabelText(fieldName);
    expect(invalidFeedback(input.element)).toBe('');
  });

  it.each([['Name'], ['Description']])(
    'validates required state for field %s when showValidation is true',
    async (fieldName) => {
      createComponent({ showValidation: true });
      const input = wrapper.findByLabelText(fieldName);
      await input.setValue('');

      expect(invalidFeedback(input.element)).toContain('is required');
    },
  );

  it.each([['default'], ['dEfAuLt'], ['Default']])(
    'rejects %s as framework name when showValidation is true',
    async (name) => {
      createComponent({ showValidation: true });
      const input = wrapper.findByLabelText('Name');
      await input.setValue(name);

      expect(invalidFeedback(input.element)).toContain('is a reserved word');
    },
  );

  it.each`
    pipelineConfigurationFullPath | message
    ${'foo.yml@bar/baz'}          | ${'Configuration not found'}
    ${'foobar'}                   | ${'Invalid format'}
  `(
    'sets the correct invalid message for pipeline when showValidation is true',
    async ({ pipelineConfigurationFullPath, message }) => {
      jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(false);
      createComponent({ showValidation: true });

      const pipelineInput = findPipelineInput();
      await pipelineInput.setValue(pipelineConfigurationFullPath);
      await waitForPromises();

      expect(invalidFeedback(pipelineInput.element)).toBe(message);
    },
  );

  it('renders section as initially expanded if is-expanded prop is true', () => {
    createComponent({ isExpanded: true });

    expect(wrapper.findComponent(EditSection).props('initiallyExpanded')).toBe(true);
  });

  describe('pipeline editing section', () => {
    it('collapses the section when there is no pipeline configuration path', () => {
      createComponent({
        value: { ...fakeFramework, pipelineConfigurationFullPath: '' },
      });

      const accordionItem = wrapper.findComponent(GlAccordionItem);
      expect(accordionItem.props('visible')).toBe(false);
    });

    it('expands the section when there is a pipeline configuration path', () => {
      createComponent({
        value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' },
      });

      const accordionItem = wrapper.findComponent(GlAccordionItem);
      expect(accordionItem.props('visible')).toBe(true);
    });
  });

  describe('maintenance mode alert', () => {
    it('renders message about suggested migration when hasMigratedPipeline is false', async () => {
      const maintenanceAlert = findMaintenanceAlert();
      const actionButton = findMigrationActionButton();

      expect(maintenanceAlert.exists()).toBe(true);
      expect(maintenanceAlert.text()).toContain('Compliance pipelines are deprecated');

      expect(actionButton.text()).toContain('Create policy');
      expect(actionButton.attributes('href')).toEqual(defaultProvides.pipelineExecutionPolicyPath);

      jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(false);
      const pipelineYAMLPath = 'file.yaml@group/project';
      const pipelineInput = findPipelineInput();
      await pipelineInput.setValue(pipelineYAMLPath);
      await waitForPromises();

      expect(actionButton.text()).toContain('Migrate pipeline to a policy');
      const urlParams = new URLSearchParams(actionButton.attributes('href').split('?')[1]);
      expect(urlParams.get('path')).toBe(pipelineYAMLPath);
      expect(urlParams.get('compliance_framework_name')).toBe(fakeFramework.name);
      expect(urlParams.get('compliance_framework_id')).toBe(fakeFramework.id.toString());
    });

    it('renders message about completing migration when hasMigratedPipeline is true and we have previous pipeline', () => {
      createComponent({
        hasMigratedPipeline: true,
        value: { ...fakeFramework, pipelineConfigurationFullPath: 'foo.yml@bar/baz' },
      });

      const maintenanceAlert = findMaintenanceAlert();
      const actionButton = findMigrationActionButton();

      expect(maintenanceAlert.exists()).toBe(true);
      expect(actionButton.exists()).toBe(false);

      expect(maintenanceAlert.text()).toContain(
        `This compliance framework's compliance pipeline has been migrated to a pipeline execution policy`,
      );
    });

    it('does not render message about completing migration when hasMigratedPipeline is true but we do not have previous pipeline', () => {
      createComponent({
        hasMigratedPipeline: true,
        value: { ...fakeFramework, pipelineConfigurationFullPath: '' },
      });

      const maintenanceAlert = findMaintenanceAlert();
      const actionButton = findMigrationActionButton();

      expect(maintenanceAlert.exists()).toBe(true);
      expect(actionButton.exists()).toBe(true);

      expect(maintenanceAlert.text()).not.toContain(
        `This compliance framework's compliance pipeline has been migrated to a pipeline execution policy`,
      );
    });
  });
});
