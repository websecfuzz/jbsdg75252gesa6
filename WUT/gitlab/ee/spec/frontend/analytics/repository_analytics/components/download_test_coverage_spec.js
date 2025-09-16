import { GlAlert, GlCollapsibleListbox, GlModal } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';

import DownloadTestCoverage from 'ee/analytics/repository_analytics/components/download_test_coverage.vue';
import SelectProjectsDropdown from 'ee/analytics/repository_analytics/components/select_projects_dropdown.vue';

describe('Download test coverage component', () => {
  let wrapper;

  const findCodeCoverageModalButton = () =>
    wrapper.findByTestId('group-code-coverage-modal-button');
  const openCodeCoverageModal = () => {
    findCodeCoverageModalButton().vm.$emit('click');
  };
  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCodeCoverageDownloadButton = () =>
    wrapper.findByTestId('group-code-coverage-download-button');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSelectProjectsDropdown = () => wrapper.findComponent(SelectProjectsDropdown);

  const injectedProperties = {
    groupAnalyticsCoverageReportsPath: '/coverage.csv',
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(DownloadTestCoverage, {
      data() {
        return {
          hasError: false,
          allProjectsSelected: false,
          selectedProjectIds: [],
        };
      },
      provide: {
        ...injectedProperties,
      },
      stubs: {
        GlModal,
        SelectProjectsDropdown: stubComponent(SelectProjectsDropdown),
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders button to open download code coverage modal', () => {
    expect(findCodeCoverageModalButton().exists()).toBe(true);
  });

  describe('when download code coverage modal is displayed', () => {
    beforeEach(() => {
      openCodeCoverageModal();
    });

    describe('when selecting a project', () => {
      const groupAnalyticsCoverageReportsPathWithDates = `${injectedProperties.groupAnalyticsCoverageReportsPath}?start_date=2020-06-06&end_date=2020-07-06`;

      describe('with all projects selected', () => {
        it('renders primary action as a link with no project_ids param', async () => {
          findSelectProjectsDropdown().vm.$emit('select-all-projects');

          await nextTick();
          expect(findCodeCoverageDownloadButton().attributes('href')).toBe(
            groupAnalyticsCoverageReportsPathWithDates,
          );
        });
      });

      describe('with two or more projects selected without selecting all projects', () => {
        it('renders primary action as a link with two project IDs as parameters', async () => {
          findSelectProjectsDropdown().vm.$emit('select-project', [1]);
          findSelectProjectsDropdown().vm.$emit('select-project', [1, 2]);

          const projectIdsQueryParam = `project_ids[]=1&project_ids[]=2`;
          const expectedPath = `${groupAnalyticsCoverageReportsPathWithDates}&${projectIdsQueryParam}`;

          await nextTick();
          expect(findCodeCoverageDownloadButton().attributes('href')).toBe(expectedPath);
        });
      });

      describe('with one project selected', () => {
        it('renders primary action as a link with one project ID as a parameter', async () => {
          findSelectProjectsDropdown().vm.$emit('select-project', [1]);

          const projectIdsQueryParam = `project_ids[]=1`;
          const expectedPath = `${groupAnalyticsCoverageReportsPathWithDates}&${projectIdsQueryParam}`;

          await nextTick();
          expect(findCodeCoverageDownloadButton().attributes('href')).toBe(expectedPath);
        });
      });

      describe('with no projects selected', () => {
        it('renders a disabled primary action button', () => {
          expect(findCodeCoverageDownloadButton().attributes('disabled')).toBeDefined();
        });
      });

      describe('when clicking the select all button', () => {
        it('selects all projects and removes the disabled attribute from the download button', async () => {
          // Simulate clicking same project twice so there are no selected project ids
          findSelectProjectsDropdown().vm.$emit('select-project', [1]);
          findSelectProjectsDropdown().vm.$emit('select-project', [1]);

          findSelectProjectsDropdown().vm.$emit('select-all-projects');

          await nextTick();
          expect(findCodeCoverageDownloadButton().attributes('href')).toBe(
            groupAnalyticsCoverageReportsPathWithDates,
          );
          expect(findCodeCoverageDownloadButton().attributes('disabled')).toBeUndefined();
        });
      });
    });

    describe('selecting date range', () => {
      it('should select date range', async () => {
        expect(findDropdown().props('toggleText')).toBe('Last 30 days');
        expect(findDropdown().props('selected')).toBe(30);

        findDropdown().vm.$emit('select', 14);

        await nextTick();

        expect(findDropdown().props('toggleText')).toBe('Last 2 weeks');
        expect(findDropdown().props('selected')).toBe(14);
      });
    });

    describe('when selecting a date range', () => {
      it.each`
        date  | expected
        ${7}  | ${`${injectedProperties.groupAnalyticsCoverageReportsPath}?start_date=2020-06-29&end_date=2020-07-06`}
        ${14} | ${`${injectedProperties.groupAnalyticsCoverageReportsPath}?start_date=2020-06-22&end_date=2020-07-06`}
        ${30} | ${`${injectedProperties.groupAnalyticsCoverageReportsPath}?start_date=2020-06-06&end_date=2020-07-06`}
        ${60} | ${`${injectedProperties.groupAnalyticsCoverageReportsPath}?start_date=2020-05-07&end_date=2020-07-06`}
        ${90} | ${`${injectedProperties.groupAnalyticsCoverageReportsPath}?start_date=2020-04-07&end_date=2020-07-06`}
      `(
        'updates CSV path to have the start date be $date days before today',
        async ({ date, expected }) => {
          findDropdown().vm.$emit('select', date);

          await nextTick();
          expect(findCodeCoverageDownloadButton().attributes('href')).toBe(expected);
        },
      );
    });

    describe('when there is an error fetching the projects', () => {
      it('displays an alert for the failed query', async () => {
        findSelectProjectsDropdown().vm.$emit('projects-query-error');

        await nextTick();
        expect(findAlert().exists()).toBe(true);
      });
    });
  });
});
