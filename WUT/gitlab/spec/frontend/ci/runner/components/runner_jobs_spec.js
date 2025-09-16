import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { TYPENAME_CI_RUNNER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import RunnerJobs from '~/ci/runner/components/runner_jobs.vue';
import RunnerJobsTable from '~/ci/runner/components/runner_jobs_table.vue';
import RunnerPagination from '~/ci/runner/components/runner_pagination.vue';
import RunnerJobsEmptyState from '~/ci/runner/components/runner_jobs_empty_state.vue';
import { captureException } from '~/ci/runner/sentry_utils';
import { RUNNER_DETAILS_JOBS_PAGE_SIZE } from '~/ci/runner/constants';

import runnerJobsQuery from '~/ci/runner/graphql/show/runner_jobs.query.graphql';

import { runnerJobsData } from '../mock_data';

jest.mock('~/alert');
jest.mock('~/ci/runner/sentry_utils');

const mockRunnerId = '1';
const mockRunnerGraphQLId = convertToGraphQLId(TYPENAME_CI_RUNNER, mockRunnerId);
const mockRunnerWithJobs = runnerJobsData.data.runner;
const mockJobs = mockRunnerWithJobs.jobs.nodes;

Vue.use(VueApollo);

describe('RunnerJobs', () => {
  let wrapper;
  let mockRunnerJobsQuery;

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findRunnerJobsTable = () => wrapper.findComponent(RunnerJobsTable);
  const findRunnerPagination = () => wrapper.findComponent(RunnerPagination);
  const findEmptyState = () => wrapper.findComponent(RunnerJobsEmptyState);
  const createComponent = ({ mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(RunnerJobs, {
      apolloProvider: createMockApollo([[runnerJobsQuery, mockRunnerJobsQuery]]),
      propsData: {
        runnerId: mockRunnerId,
      },
      stubs: {
        CrudComponent,
      },
    });
  };

  beforeEach(() => {
    mockRunnerJobsQuery = jest.fn();
  });

  afterEach(() => {
    mockRunnerJobsQuery.mockReset();
  });

  it('Requests runner jobs', async () => {
    createComponent();

    await waitForPromises();

    expect(mockRunnerJobsQuery).toHaveBeenCalledTimes(1);
    expect(mockRunnerJobsQuery).toHaveBeenCalledWith({
      id: mockRunnerGraphQLId,
      first: RUNNER_DETAILS_JOBS_PAGE_SIZE,
    });
  });

  describe('When there are jobs assigned', () => {
    beforeEach(async () => {
      mockRunnerJobsQuery.mockResolvedValueOnce(runnerJobsData);

      createComponent();
      await waitForPromises();
    });

    it('shows count', () => {
      expect(findCrudComponent().props('count')).toBe(1);
    });

    it('Shows jobs', () => {
      const jobs = findRunnerJobsTable().props('jobs');

      expect(jobs).toEqual(mockJobs);
    });

    describe('When "Next" page is clicked', () => {
      beforeEach(async () => {
        findRunnerPagination().vm.$emit('input', { page: 2, after: 'AFTER_CURSOR' });

        await waitForPromises();
      });

      it('A new page is requested', () => {
        expect(mockRunnerJobsQuery).toHaveBeenCalledTimes(2);
        expect(mockRunnerJobsQuery).toHaveBeenLastCalledWith({
          id: mockRunnerGraphQLId,
          first: RUNNER_DETAILS_JOBS_PAGE_SIZE,
          after: 'AFTER_CURSOR',
        });
      });
    });
  });

  describe('When loading', () => {
    it('shows loading indicator and no other content', () => {
      createComponent();

      expect(findCrudComponent().props('isLoading')).toBe(true);
      expect(findRunnerJobsTable().exists()).toBe(false);
      expect(findRunnerPagination().attributes('disabled')).toBeDefined();
    });
  });

  describe('When there are no jobs', () => {
    beforeEach(async () => {
      mockRunnerJobsQuery.mockResolvedValueOnce({
        data: {
          runner: {
            id: mockRunnerId,
            projectCount: 0,
            jobCount: 0,
            jobs: {
              nodes: [],
              pageInfo: {
                hasNextPage: false,
                hasPreviousPage: false,
                startCursor: '',
                endCursor: '',
              },
            },
          },
        },
      });

      createComponent();
      await waitForPromises();
    });

    it('shows no count', () => {
      expect(findCrudComponent().props('count')).toBe('');
    });

    it('should render empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });
  });

  describe('When an error occurs', () => {
    beforeEach(async () => {
      mockRunnerJobsQuery.mockRejectedValue(new Error('Error!'));

      createComponent();
      await waitForPromises();
    });

    it('shows no count', () => {
      expect(findCrudComponent().props('count')).toBe('');
    });

    it('shows an error', () => {
      expect(createAlert).toHaveBeenCalled();
    });

    it('reports an error', () => {
      expect(captureException).toHaveBeenCalledWith({
        component: 'RunnerJobs',
        error: expect.any(Error),
      });
    });
  });
});
