import { nextTick } from 'vue';
import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { mockTracking } from 'helpers/tracking_helper';

import { HTTP_STATUS_CREATED, HTTP_STATUS_FORBIDDEN } from '~/lib/utils/http_status';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';

import { saveProductAnalyticsVisualization } from 'ee/analytics/analytics_dashboards/api/dashboards_api';
import { fetchFilterOptions } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';

import AnalyticsDataExplorer from 'ee/analytics/analytics_dashboards/components/analytics_data_explorer.vue';
import VisualizationTypeSelector from 'ee/analytics/analytics_dashboards/components/data_explorer/analytics_visualization_type_selector.vue';
import AiCubeQueryGenerator from 'ee/analytics/analytics_dashboards/components/data_explorer/ai_cube_query_generator.vue';
import {
  EVENT_LABEL_USER_VIEWED_DATA_EXPLORER,
  EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION,
} from 'ee/analytics/analytics_dashboards/constants';
import { NEW_DASHBOARD_SLUG } from '~/vue_shared/components/customizable_dashboard/constants';

import { mockFilterOptions, TEST_CUSTOM_DASHBOARDS_PROJECT } from '../mock_data';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_action');

// Note: there is a circular dependency issue causing "Object.defineProperty(window, 'pendingApolloRequests'" to run multiple times, which throws an error
// This jest.mock works around the issue by preventing the module from running at all.
jest.mock('~/lib/graphql');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));
jest.mock('ee/analytics/analytics_dashboards/api/dashboards_api');
jest.mock('ee/analytics/analytics_dashboards/data_sources/cube_analytics');

const showToast = jest.fn();
const routerPush = jest.fn();

describe('AnalyticsDataExplorer', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let trackingSpy;

  const findTitleFormGroup = () => wrapper.findByTestId('visualization-title-form-group');
  const findTitleInput = () => wrapper.findByTestId('visualization-title-input');
  const findFilteredSearch = () => wrapper.findByTestId('visualization-filtered-search');
  const findSaveButton = () => wrapper.findByTestId('visualization-save-btn');
  const findCancelButton = () => wrapper.findByTestId('visualization-cancel-btn');
  const findTypeSelector = () => wrapper.findComponent(VisualizationTypeSelector);
  const findPageTitle = () => wrapper.findByTestId('page-title');
  const findPageDescription = () => wrapper.findByTestId('page-description');
  const findPageDescriptionLink = () => findPageDescription().findComponent(GlLink);
  const findAiQueryGenerator = () => wrapper.findComponent(AiCubeQueryGenerator);

  const setVisualizationTitle = async (newTitle = '') => {
    await findTitleInput().vm.$emit('input', newTitle);
  };

  const setVisualizationType = async (newType) => {
    await findTypeSelector().vm.$emit('input', newType);
  };

  const setAllRequiredFieldsWithFilter = async () => {
    await setVisualizationTitle('New Title');
    await setVisualizationType('SingleStat');
    await findFilteredSearch().vm.$emit('input', { measures: ['Sessions.count'], limit: 100 });
  };

  const mockSaveVisualizationImplementation = async (responseCallback) => {
    saveProductAnalyticsVisualization.mockImplementation(responseCallback);

    await waitForPromises();
  };

  const saveVisualization = async () => {
    await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));
    await findSaveButton().vm.$emit('click');
    return waitForPromises();
  };

  const mockFetchFilterOptions = async (responseCallback) => {
    fetchFilterOptions.mockImplementation(responseCallback);

    await waitForPromises();
  };

  const createWrapper = async (
    sourceDashboardSlug = '',
    options = { provide: {}, setMetaResponse: true },
  ) => {
    const mocks = {
      $toast: {
        show: showToast,
      },
      $route: {
        params: {
          dashboard: sourceDashboardSlug,
        },
      },
      $router: {
        push: routerPush,
      },
    };

    if (options.setMetaResponse) {
      await mockFetchFilterOptions(() => mockFilterOptions);
    }

    wrapper = shallowMountExtended(AnalyticsDataExplorer, {
      stubs: {
        RouterView: true,
        GlSprintf,
        VisualizationTypeSelector: stubComponent(VisualizationTypeSelector, {
          template: `<div><button>Dropdown</button></div>`,
        }),
      },
      mocks,
      provide: {
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
        aiGenerateCubeQueryEnabled: false,
        ...options.provide,
      },
    });
  };

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, window.document, jest.spyOn);
  });

  describe('when mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the page title', () => {
      expect(findPageTitle().text()).toBe('Create your visualization');
    });

    it('renders the page description with a link to user documentation', () => {
      expect(findPageDescription().text()).toContain(
        'Use the data explorer to create custom visualizations. After you save a visualization, you can add it to a dashboard.',
      );

      expect(findPageDescriptionLink().text()).toBe('Learn more');
      expect(findPageDescriptionLink().attributes('href')).toBe(
        helpPagePath('user/analytics/analytics_dashboards'),
      );
    });

    it('renders title input', () => {
      expect(findTitleInput().exists()).toBe(true);
    });

    it('renders the filtered search', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('render a cancel button that routes to the dashboard listing page', async () => {
      const button = findCancelButton();
      expect(button.exists()).toBe(true);
      expect(button.text()).toBe('Cancel');
      expect(button.attributes('category')).toBe('secondary');

      await button.vm.$emit('click');

      expect(routerPush).toHaveBeenCalledWith('/');
    });

    it(`tracks the "${EVENT_LABEL_USER_VIEWED_DATA_EXPLORER}" event`, () => {
      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        EVENT_LABEL_USER_VIEWED_DATA_EXPLORER,
        expect.any(Object),
      );
    });

    describe('beforeDestroy', () => {
      it('should dismiss the alert', async () => {
        await setVisualizationTitle('New Title');
        await findSaveButton().vm.$emit('click');

        wrapper.destroy();

        await nextTick();

        expect(mockAlertDismiss).toHaveBeenCalled();
      });
    });
  });

  describe('when meta call fails during mounting', () => {
    const networkError = new Error(`Network error`);

    beforeEach(async () => {
      await mockFetchFilterOptions(() => {
        throw networkError;
      });

      await createWrapper('', { provide: {}, setMetaResponse: false });
    });

    it('alerts the user to the issue', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while loading data',
        error: networkError,
        captureError: true,
      });
    });
  });

  describe('when saving', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('and there is no title', () => {
      beforeEach(() => {
        findTitleInput().element.focus = jest.fn();

        return findSaveButton().vm.$emit('click');
      });

      it('does not save the dashboard', () => {
        expect(saveProductAnalyticsVisualization).not.toHaveBeenCalled();
      });

      it('shows the invalid state on the title input', () => {
        expect(findTitleFormGroup().attributes('state')).toBe(undefined);
        expect(findTitleFormGroup().attributes('invalid-feedback')).toBe('This field is required.');

        expect(findTitleInput().attributes('state')).toBe(undefined);
      });

      it('sets focus on the dashboard title input', () => {
        expect(findTitleInput().element.focus).toHaveBeenCalled();
      });

      describe('and a user then inputs a title', () => {
        beforeEach(() => setVisualizationTitle('New Title'));

        it('shows title input as valid', () => {
          expect(findTitleFormGroup().attributes('state')).toBe('true');
          expect(findTitleInput().attributes('state')).toBe('true');
        });
      });
    });

    it('creates an alert when the measurement is not selected', async () => {
      await setVisualizationTitle('New Title');

      await findSaveButton().vm.$emit('click');
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Select a measurement',
        captureError: false,
        error: null,
      });
    });

    describe('when the visualization is valid', () => {
      describe('and it saved successfully', () => {
        beforeEach(async () => {
          await setAllRequiredFieldsWithFilter();

          return saveVisualization();
        });

        it('creates the visualization file and shows a success toast', () => {
          expect(saveProductAnalyticsVisualization).toHaveBeenCalledWith(
            'new_title',
            {
              data: {
                query: { limit: 100, measures: ['Sessions.count'] },
                type: 'cube_analytics',
              },
              options: {},
              type: 'SingleStat',
              version: 1,
            },
            TEST_CUSTOM_DASHBOARDS_PROJECT,
          );

          expect(showToast).toHaveBeenCalledWith('Visualization was saved successfully');
        });

        it(`tracks the "${EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION}" event`, () => {
          expect(trackingSpy).toHaveBeenCalledWith(
            undefined,
            EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION,
            expect.any(Object),
          );
        });
      });

      it('dismisses the existing alert after successfully saving', async () => {
        await setVisualizationTitle('New Title');
        await findSaveButton().vm.$emit('click');

        await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

        await setAllRequiredFieldsWithFilter();
        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(mockAlertDismiss).toHaveBeenCalled();
      });

      it('and a error happens', async () => {
        await setAllRequiredFieldsWithFilter();
        await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_FORBIDDEN }));

        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error while saving visualization.',
          error: new Error(
            `Received an unexpected HTTP status while saving visualization: ${HTTP_STATUS_FORBIDDEN}`,
          ),
          captureError: true,
        });
      });

      it('and the server responds with "A file with this name already exists"', async () => {
        await setAllRequiredFieldsWithFilter();
        const responseError = new Error();
        responseError.response = {
          data: { message: 'A file with this name already exists' },
        };

        mockSaveVisualizationImplementation(() => {
          throw responseError;
        });

        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(findTitleFormGroup().attributes('state')).toBe(undefined);
        expect(findTitleFormGroup().attributes('invalid-feedback')).toBe(
          'A visualization with that name already exists.',
        );
        expect(findTitleInput().attributes('state')).toBe(undefined);
      });

      it('and an error is thrown', async () => {
        await setAllRequiredFieldsWithFilter();
        const newError = new Error();
        mockSaveVisualizationImplementation(() => {
          throw newError;
        });
        await findSaveButton().vm.$emit('click');
        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          error: newError,
          message: 'Error while saving visualization.',
          captureError: true,
        });
      });
    });
  });

  describe('when cancelling', () => {
    let windowDialogSpy;
    let beforeUnloadEvent;

    beforeEach(async () => {
      beforeUnloadEvent = new Event('beforeunload');
      windowDialogSpy = jest.spyOn(beforeUnloadEvent, 'returnValue', 'set');
      await createWrapper();
      confirmAction.mockReturnValue(new Promise(() => {}));
    });

    afterEach(() => {
      windowDialogSpy.mockRestore();
      confirmAction.mockReset();
    });

    describe('by the "beforeunload" event', () => {
      it('does not show the browser confirm dialog when there are no changes', () => {
        window.dispatchEvent(beforeUnloadEvent);

        expect(windowDialogSpy).not.toHaveBeenCalled();
      });

      it('shows the browser confirm dialog when there are changes', async () => {
        await setVisualizationTitle('New Title');
        window.dispatchEvent(beforeUnloadEvent);

        expect(windowDialogSpy).toHaveBeenCalledWith(
          'Are you sure you want to lose unsaved changes?',
        );
      });
    });

    describe('by the route changing', () => {
      const nextMock = jest.fn();

      it('does not show confirm dialog if there are no changes', () => {
        wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);

        expect(confirmAction).not.toHaveBeenCalled();
      });

      it('shows the confirm dialog if there are changes', async () => {
        await setVisualizationTitle('New Title');
        wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);

        expect(confirmAction).toHaveBeenCalledWith(
          'Are you sure you want to cancel creating this visualization?',
          {
            cancelBtnText: 'Continue creating',
            primaryBtnText: 'Discard changes',
          },
        );
      });

      it('does nothing if the user opts to keep creating', async () => {
        await setVisualizationTitle('New Title');
        confirmAction.mockResolvedValue(false);

        wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);
        await waitForPromises();

        expect(routerPush).not.toHaveBeenCalled();
      });
    });
  });

  describe('when editing for dashboard', () => {
    const setupSaveDashboard = async (dashboard) => {
      await createWrapper(dashboard);
      await setAllRequiredFieldsWithFilter();

      await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

      await findSaveButton().vm.$emit('click');
      await waitForPromises();
    };

    it('after save it will redirect for new dashboards', async () => {
      await setupSaveDashboard(NEW_DASHBOARD_SLUG);

      expect(routerPush).toHaveBeenCalledWith('/new');
    });

    it('after save it will redirect for existing dashboards', async () => {
      await setupSaveDashboard('test-source-dashboard');

      expect(routerPush).toHaveBeenCalledWith({
        name: 'dashboard-detail',
        params: {
          slug: 'test-source-dashboard',
          editing: true,
        },
      });
    });
  });

  describe('natural language querying', () => {
    it.each`
      providedFlagState | visibility
      ${true}           | ${'shows'}
      ${false}          | ${'hides'}
    `(
      '$visibility the AI cube query generator when "aiGenerateCubeQueryEnabled" is "$providedFlagState"',
      async ({ providedFlagState }) => {
        await createWrapper('', {
          provide: {
            aiGenerateCubeQueryEnabled: providedFlagState,
          },
          setMetaResponse: true,
        });

        expect(findAiQueryGenerator().exists()).toBe(providedFlagState);
      },
    );

    it('will not prompt user when there are no existing changes to the query', async () => {
      await createWrapper('', {
        provide: {
          aiGenerateCubeQueryEnabled: true,
        },
        setMetaResponse: true,
      });

      expect(findAiQueryGenerator().props('warnBeforeReplacingQuery')).toBe(false);
    });

    it('ensures user will be prompted before generating when there are unsaved changes', async () => {
      await createWrapper('', {
        provide: {
          aiGenerateCubeQueryEnabled: true,
        },
        setMetaResponse: true,
      });
      await setAllRequiredFieldsWithFilter();

      expect(findAiQueryGenerator().props('warnBeforeReplacingQuery')).toBe(true);
    });
  });

  describe('clear fields after saving', () => {
    const expectTitleAndTypeReset = () => {
      expect(findTitleInput().attributes('value')).toBe('');
      expect(findTypeSelector().props('value')).toBe('DataTable');
    };

    describe('default behaviour', () => {
      beforeEach(async () => {
        await createWrapper();
        await setAllRequiredFieldsWithFilter();
        return saveVisualization();
      });

      it('resets the designer fields to their initial state', () => {
        expectTitleAndTypeReset();

        expect(findFilteredSearch().props('query')).toStrictEqual({ limit: 100 });
      });
    });

    describe('when "aiGenerateCubeQueryEnabled" feature is enabled', () => {
      beforeEach(async () => {
        await createWrapper('', {
          provide: {
            aiGenerateCubeQueryEnabled: true,
          },
          setMetaResponse: true,
        });
        await setAllRequiredFieldsWithFilter();
        await findAiQueryGenerator().vm.$emit('input', 'Hello world');
        return saveVisualization();
      });

      it('resets the designer fields + AI prompt to their initial state', () => {
        expectTitleAndTypeReset();

        expect(findFilteredSearch().props('query')).toStrictEqual({ limit: 100 });

        expect(findAiQueryGenerator().props('value')).toBe('');
      });
    });
  });
});
