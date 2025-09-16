import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { visitUrl } from '~/lib/utils/url_utility';
import PromoteRun from '~/ml/experiment_tracking/routes/candidates/promote/promote_run.vue';
import ModelSelectionDropdown from '~/ml/experiment_tracking/routes/candidates/promote/model_selection_dropdown.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import createModelVersionMutation from '~/ml/experiment_tracking/graphql/mutations/promote_model_version.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import { createModelVersionResponses } from 'jest/ml/model_registry/graphql_mock_data';
import { newCandidate } from 'jest/ml/model_registry/mock_data';
import { model42 } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

describe('PromoteRun', () => {
  let wrapper;
  let apolloProvider;
  const successfulResolver = jest.fn().mockResolvedValue(createModelVersionResponses.success);

  beforeEach(() => {
    jest.spyOn(Sentry, 'captureException').mockImplementation();
  });

  afterEach(() => {
    apolloProvider = null;
  });

  const createWrapper = (createResolver = successfulResolver, withModel = true) => {
    const requestHandlers = [[createModelVersionMutation, createResolver]];
    apolloProvider = createMockApollo(requestHandlers);

    wrapper = shallowMountExtended(PromoteRun, {
      propsData: {
        candidate: newCandidate(withModel),
      },
      apolloProvider,
      stubs: {
        PageHeading,
      },
    });
  };

  const findDescription = () => wrapper.findByTestId('page-heading-description');
  const findPrimaryButton = () => wrapper.findByTestId('primary-button');
  const findSecondaryButton = () => wrapper.findByTestId('secondary-button');
  const findVersionInput = () => wrapper.findByTestId('versionId');
  const findDescriptionInput = () => wrapper.findByTestId('descriptionId');
  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const submitForm = async () => {
    findPrimaryButton().vm.$emit('click');
    await waitForPromises();
  };
  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findModelSelection = () => wrapper.findByTestId('modelSelectionDescriptionId');
  const findModelSelectionDropdown = () => wrapper.findComponent(ModelSelectionDropdown);
  const findVersionDescription = () => wrapper.findByTestId('versionDescriptionId');

  describe('Initial state', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('Form', () => {
      it('renders the title', () => {
        expect(wrapper.findByRole('heading').text()).toBe('Promote run');
      });

      it('renders the description', () => {
        expect(findDescription().text()).toBe(
          'Complete the form below to promote run to a model version.',
        );
      });

      it('renders the version input', () => {
        expect(findVersionInput().exists()).toBe(true);
      });

      it('renders the version input label for initial state', () => {
        expect(findVersionDescription().attributes().description).toBe(
          'Must be a semantic version. Latest version is 1.0.2',
        );
        expect(findVersionDescription().attributes('invalid-feedback')).toBe('');
        expect(findVersionDescription().attributes('valid-feedback')).toBe('');
      });

      it('renders the description input', () => {
        expect(findDescriptionInput().exists()).toBe(true);
      });

      it('renders the create button', () => {
        expect(findPrimaryButton().props()).toMatchObject({
          variant: 'confirm',
          disabled: true,
        });
      });

      it('renders the cancel button', () => {
        expect(findSecondaryButton().props()).toMatchObject({
          variant: 'default',
          disabled: false,
        });
      });

      it('disables the create button in the modal when semver is incorrect', () => {
        expect(findPrimaryButton().props()).toMatchObject({
          variant: 'confirm',
          disabled: true,
        });
      });

      it('does not render the alert by default', () => {
        expect(findGlAlert().exists()).toBe(false);
      });

      it('renders the candidate model name', () => {
        expect(findModelSelection().text()).toBe('CoolModel');
      });

      it('does not display model selection dropdown', () => {
        expect(findModelSelectionDropdown().exists()).toBe(false);
      });
    });
  });

  describe('Markdown editor', () => {
    it('should show markdown editor', () => {
      createWrapper();

      expect(findMarkdownEditor().exists()).toBe(true);

      expect(findMarkdownEditor().props()).toMatchObject({
        enableContentEditor: true,
        formFieldProps: {
          id: 'model-version-description',
          name: 'model-version-description',
          placeholder: 'Enter a model version description',
        },
        markdownDocsPath: '/help/user/markdown',
        renderMarkdownPath: '/markdown-preview',
        uploadsPath: '',
      });
    });
  });

  describe('It reacts to semantic version input', () => {
    beforeEach(() => {
      createWrapper();
    });
    it('renders the version input label for initial state', () => {
      expect(findVersionDescription().attributes('invalid-feedback')).toBe('');
      expect(findPrimaryButton().props()).toMatchObject({
        variant: 'confirm',
        disabled: true,
      });
    });
    it.each(['1.0', '1', 'abc', '1.abc', '1.0.0.0'])(
      'renders the version input label for invalid state',
      async (version) => {
        findVersionInput().vm.$emit('input', version);
        await nextTick();
        expect(findVersionDescription().attributes('invalid-feedback')).toBe(
          'Version is not a valid semantic version.',
        );
        expect(findPrimaryButton().props()).toMatchObject({
          variant: 'confirm',
          disabled: true,
        });
      },
    );
    it.each(['1.0.0', '0.0.0-b', '24.99.99-b99'])(
      'renders the version input label for valid state',
      async (version) => {
        findVersionInput().vm.$emit('input', version);
        await nextTick();
        expect(findVersionDescription().attributes('valid-feedback')).toBe(
          'Version is valid semantic version.',
        );
        expect(findPrimaryButton().props()).toMatchObject({
          variant: 'confirm',
          disabled: false,
        });
      },
    );
  });

  describe('Successful flow', () => {
    beforeEach(async () => {
      createWrapper();
      findVersionInput().vm.$emit('input', '1.0.0');
      findDescriptionInput().vm.$emit('input', 'My model version description');

      await submitForm();
    });

    it('makes a create mutation upon confirm', () => {
      expect(successfulResolver).toHaveBeenCalledWith({
        modelId: 'gid://gitlab/Ml::Model/1',
        projectPath: 'some/project',
        version: '1.0.0',
        description: 'My model version description',
        candidateId: 'gid://gitlab/Ml::Candidate/1',
      });
    });

    it('visits the model versions page upon successful create mutation', async () => {
      createWrapper();

      await submitForm();

      expect(visitUrl).toHaveBeenCalledWith('/some/project/-/ml/models/1/versions/1');
    });

    it('clicking on secondary button clears the form', async () => {
      createWrapper();

      await findSecondaryButton().vm.$emit('click');

      expect(visitUrl).toHaveBeenCalledWith('/some/project/-/ml/models/1/versions/1');
    });
  });

  describe('Failed flow', () => {
    it('displays an alert upon failed create mutation', async () => {
      const failedCreateResolver = jest.fn().mockResolvedValue(createModelVersionResponses.failure);
      createWrapper(failedCreateResolver);

      findVersionInput().vm.$emit('input', '1.0.0');

      await submitForm();

      expect(findGlAlert().text()).toBe('Version is invalid');
    });
  });

  describe('Graphql query error', () => {
    const error = new Error('Failed to fetch');

    beforeEach(async () => {
      const errorResolver = jest.fn().mockRejectedValue(error);
      createWrapper(errorResolver);

      findVersionInput().vm.$emit('input', '1.0.0');

      await submitForm();
    });

    it('logs a Sentry error', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('Standalone experiment', () => {
    beforeEach(() => {
      createWrapper(undefined, false);
    });

    it('renders the model name', () => {
      expect(findModelSelection().attributes()).toMatchObject({
        description:
          'Select the model that will contain the new version. The run will move to the default experiment of that model.',
        label: 'Model',
      });
    });

    it('renders the model selection dropdown', () => {
      expect(findModelSelectionDropdown().props()).toMatchObject({
        projectPath: 'some/project',
        value: null,
      });
    });

    it('renders the version input label for initial state', () => {
      expect(findVersionDescription().attributes().description).toBe('Must be a semantic version.');
    });

    it('makes a create mutation with selected model', async () => {
      findVersionInput().vm.$emit('input', '1.0.0');
      findDescriptionInput().vm.$emit('input', 'My model version description');
      findModelSelectionDropdown().vm.$emit('input', model42);

      await submitForm();

      expect(successfulResolver).toHaveBeenCalledWith({
        modelId: 'gid://gitlab/Ml::Model/42',
        projectPath: 'some/project',
        version: '1.0.0',
        description: 'My model version description',
        candidateId: 'gid://gitlab/Ml::Candidate/1',
      });
    });
  });
});
