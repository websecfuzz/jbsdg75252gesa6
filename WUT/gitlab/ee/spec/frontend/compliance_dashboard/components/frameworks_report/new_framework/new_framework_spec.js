import { GlSprintf, GlLink } from '@gitlab/ui';
import PROJECT_CREATE_NEW_SVG_URL from '@gitlab/svgs/dist/illustrations/project-create-new-sm.svg?url';
import PROJECT_IMPORT_SVG_URL from '@gitlab/svgs/dist/illustrations/project-import-sm.svg?url';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert, VARIANT_DANGER, VARIANT_SUCCESS } from '~/alert';
import NewFramework from 'ee/compliance_dashboard/components/frameworks_report/new_framework/new_framework.vue';
import axios from '~/lib/utils/axios_utils';
import { ROUTE_BLANK_FRAMEWORK, ROUTE_EDIT_FRAMEWORK } from 'ee/compliance_dashboard/constants';

jest.mock('~/alert');
jest.mock('~/lib/utils/axios_utils', () => ({
  post: jest.fn(),
}));

describe('NewFramework', () => {
  let wrapper;
  const $router = {
    push: jest.fn(),
  };
  const frameworkImportUrl = '/groups/123/compliance_frameworks/import';

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(NewFramework, {
      propsData: {
        ...props,
      },
      provide: {
        frameworkImportUrl,
        ...provide,
      },
      mocks: {
        $router,
      },
      stubs: {
        GlSprintf,
        GlLink,
      },
    });
  };

  const findPageTitle = () => wrapper.findByTestId('new-framework-page-title');
  const findCreateBlankFrameworkPanel = () => wrapper.findByTestId('new-framework-blank_framework');
  const findImportFrameworkPanel = () => wrapper.findByTestId('new-framework-import_framework');
  const findComplianceAdherenceTemplatesLink = () =>
    wrapper.findByTestId('compliance-adherence-templates-link');
  const findNewFrameworkFileInput = () => wrapper.findByTestId('new-framework-file-input');

  const createMockFile = () => {
    const mockFile = new File(['{}'], 'test.json', { type: 'application/json' });

    Object.defineProperty(findNewFrameworkFileInput().element, 'files', {
      value: [mockFile],
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the component title correctly', () => {
    expect(findPageTitle().text()).toBe('Create new framework');
  });

  it('renders create blank framework panel correctly', () => {
    expect(findCreateBlankFrameworkPanel().find('img').element.src).toBe(
      PROJECT_CREATE_NEW_SVG_URL,
    );
    expect(findCreateBlankFrameworkPanel().find('img').element.alt).toBe('Create blank framework');
    expect(findCreateBlankFrameworkPanel().text()).toContain('Create blank framework');
    expect(findCreateBlankFrameworkPanel().text()).toContain(
      'Create a new compliance framework from scratch to define your compliance requirements.',
    );
  });

  it('renders import framework panel correctly', () => {
    expect(findImportFrameworkPanel().find('img').element.src).toBe(PROJECT_IMPORT_SVG_URL);
    expect(findImportFrameworkPanel().find('img').element.alt).toBe('Import framework');
    expect(findImportFrameworkPanel().text()).toContain('Import framework');
    expect(findImportFrameworkPanel().text()).toContain(
      'Import an existing compliance framework from a JSON file.',
    );
  });

  it('renders the compliance adherence templates link', () => {
    expect(findComplianceAdherenceTemplatesLink().attributes('href')).toBe(
      'https://gitlab.com/gitlab-org/software-supply-chain-security/compliance/engineering/compliance-adherence-templates',
    );
  });

  describe('panel navigation', () => {
    it('navigates to blank framework form when create blank framework panel is clicked', async () => {
      await findCreateBlankFrameworkPanel().trigger('click');

      expect($router.push).toHaveBeenCalledWith({ name: ROUTE_BLANK_FRAMEWORK });
    });

    it('triggers file upload when import framework panel is clicked', async () => {
      findNewFrameworkFileInput().element.click = jest.fn();

      await findImportFrameworkPanel().trigger('click');

      expect(findNewFrameworkFileInput().element.click).toHaveBeenCalled();
    });
  });

  describe('when import framework panel is clicked', () => {
    it('shows error alert when frameworkImportUrl is not available', async () => {
      createComponent({
        provide: {
          frameworkImportUrl: null,
        },
      });

      createMockFile();

      await findNewFrameworkFileInput().trigger('change');

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Unable to determine the correct upload URL. Please try again.',
        variant: VARIANT_DANGER,
      });
    });

    it('successfully imports framework and redirects', async () => {
      const frameworkId = 42;
      axios.post.mockResolvedValue({
        data: {
          framework_id: frameworkId,
        },
      });

      createMockFile();

      await findNewFrameworkFileInput().trigger('change');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Framework imported successfully.',
        variant: VARIANT_SUCCESS,
      });

      expect(wrapper.vm.$router.push).toHaveBeenCalledWith({
        name: ROUTE_EDIT_FRAMEWORK,
        params: { id: frameworkId },
      });
    });

    it('shows error alert with message when present in response', async () => {
      const frameworkId = 42;
      const errorMessage = 'Control validation errors detected';
      axios.post.mockResolvedValue({
        data: {
          framework_id: frameworkId,
          message: errorMessage,
        },
      });

      createMockFile();

      await findNewFrameworkFileInput().trigger('change');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        variant: VARIANT_DANGER,
      });
    });

    it('shows error for API failure with response message', async () => {
      axios.post.mockRejectedValue({
        response: {
          data: {
            message: 'No template file provided',
          },
        },
      });

      createMockFile();

      await findNewFrameworkFileInput().trigger('change');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'No template file provided',
        variant: VARIANT_DANGER,
      });
    });

    it('shows error for API failure with error message', async () => {
      axios.post.mockRejectedValue({
        message: 'Network error',
      });

      createMockFile();

      await findNewFrameworkFileInput().trigger('change');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to import framework file. Network error',
        variant: VARIANT_DANGER,
      });
    });

    it('handles case when no file is selected', async () => {
      await findNewFrameworkFileInput().trigger('change');
      await waitForPromises();

      expect(axios.post).not.toHaveBeenCalled();
      expect(createAlert).not.toHaveBeenCalled();
    });
  });
});
