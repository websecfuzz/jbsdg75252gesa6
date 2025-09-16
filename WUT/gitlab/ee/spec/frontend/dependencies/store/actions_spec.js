import MockAdapter from 'axios-mock-adapter';
import { sortBy } from 'lodash';
import axios from '~/lib/utils/axios_utils';
import * as actions from 'ee/dependencies/store/actions';
import projectDependencies from 'ee/dependencies/graphql/project_dependencies.query.graphql';
import groupDependencies from 'ee/dependencies/graphql/group_dependencies.query.graphql';
import dependencyVulnerabilities from 'ee/dependencies/graphql/dependency_vulnerabilities.query.graphql';
import {
  EXPORT_STARTED_MESSAGE,
  FETCH_ERROR_MESSAGE,
  FETCH_EXPORT_ERROR_MESSAGE,
  LICENSES_FETCH_ERROR_MESSAGE,
  SORT_DESCENDING,
  VULNERABILITIES_FETCH_ERROR_MESSAGE,
} from 'ee/dependencies/store/constants';
import * as types from 'ee/dependencies/store/mutation_types';
import getInitialState from 'ee/dependencies/store/state';
import { TEST_HOST } from 'helpers/test_constants';
import testAction from 'helpers/vuex_action_helper';
import { createAlert, VARIANT_INFO } from '~/alert';
import { graphQLClient } from 'ee/dependencies/store/utils';
import download from '~/lib/utils/downloader';
import {
  HTTP_STATUS_CREATED,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';

import mockDependenciesResponse from './mock_dependencies.json';
import mockGraphQLDependenciesResponse from './mock_graphql_dependencies.json';

jest.mock('~/alert');
jest.mock('~/lib/utils/downloader');
jest.mock('ee/dependencies/store/utils', () => ({
  graphQLClient: {
    query: jest.fn(),
  },
  isValidResponse: jest.requireActual('ee/dependencies/store/utils').isValidResponse,
}));
jest.mock('~/graphql_shared/utils', () => ({
  getIdFromGraphQLId: jest.fn(() => 'extracted-from-get-id-from-graphql-id-util'),
  convertToGraphQLId: jest.fn(() => 'extracted-from-convert-to-graphql-id-util'),
}));

describe('Dependencies actions', () => {
  const pageInfo = {
    page: 3,
    nextPage: 2,
    previousPage: 1,
    perPage: 20,
    total: 100,
    totalPages: 5,
    type: 'offset',
  };

  const headers = {
    'X-Next-Page': pageInfo.nextPage,
    'X-Page': pageInfo.page,
    'X-Per-Page': pageInfo.perPage,
    'X-Prev-Page': pageInfo.previousPage,
    'X-Total': pageInfo.total,
    'X-Total-Pages': pageInfo.totalPages,
  };

  const cursorHeaders = {
    'X-Next-Page': 'eyJpZCI6IjYyIiwiX2tkIjoibiJ9',
    'X-Page': 'eyJpZCI6IjQyIiwiX2tkIjoibiJ9',
    'X-Page-Type': 'cursor',
    'X-Per-Page': 20,
    'X-Prev-Page': 'eyJpZCI6IjQyIiwiX2tkIjoicCJ9',
  };

  const mockResponseExportEndpoint = {
    id: 1,
    has_finished: true,
    self: '/dependency_list_exports/1',
    download: '/dependency_list_exports/1/download',
  };

  afterEach(() => {
    createAlert.mockClear();
    download.mockClear();
  });

  describe('setDependenciesEndpoint', () => {
    it('commits the SET_DEPENDENCIES_ENDPOINT mutation', () =>
      testAction(
        actions.setDependenciesEndpoint,
        TEST_HOST,
        getInitialState(),
        [
          {
            type: types.SET_DEPENDENCIES_ENDPOINT,
            payload: TEST_HOST,
          },
        ],
        [],
      ));
  });

  describe('setExportDependenciesEndpoint', () => {
    it('commits the SET_EXPORT_DEPENDENCIES_ENDPOINT mutation', () =>
      testAction(
        actions.setExportDependenciesEndpoint,
        TEST_HOST,
        getInitialState(),
        [
          {
            type: types.SET_EXPORT_DEPENDENCIES_ENDPOINT,
            payload: TEST_HOST,
          },
        ],
        [],
      ));
  });

  describe('requestDependencies', () => {
    it('commits the REQUEST_DEPENDENCIES mutation', () =>
      testAction(
        actions.requestDependencies,
        undefined,
        getInitialState(),
        [
          {
            type: types.REQUEST_DEPENDENCIES,
          },
        ],
        [],
      ));
  });

  describe('receiveDependenciesSuccess', () => {
    it('commits the RECEIVE_DEPENDENCIES_SUCCESS mutation', () =>
      testAction(
        actions.receiveDependenciesSuccess,
        { headers, data: mockDependenciesResponse },
        getInitialState(),
        [
          {
            type: types.RECEIVE_DEPENDENCIES_SUCCESS,
            payload: {
              dependencies: mockDependenciesResponse.dependencies,
              pageInfo,
            },
          },
        ],
        [],
      ));

    describe('with cursor pagination headers', () => {
      it('commits the correct pagination info', () => {
        testAction(
          actions.receiveDependenciesSuccess,
          {
            headers: cursorHeaders,
            data: mockDependenciesResponse,
          },
          getInitialState(),
          [
            {
              type: types.RECEIVE_DEPENDENCIES_SUCCESS,
              payload: {
                dependencies: mockDependenciesResponse.dependencies,
                pageInfo: {
                  type: 'cursor',
                  currentCursor: cursorHeaders['X-Page'],
                  endCursor: cursorHeaders['X-Next-Page'],
                  hasNextPage: true,
                  hasPreviousPage: true,
                  startCursor: cursorHeaders['X-Prev-Page'],
                },
              },
            },
          ],
          [],
        );
      });
    });
  });

  describe('receiveDependenciesError', () => {
    it('commits the RECEIVE_DEPENDENCIES_ERROR mutation', () => {
      const error = { error: true };

      return testAction(
        actions.receiveDependenciesError,
        error,
        getInitialState(),
        [
          {
            type: types.RECEIVE_DEPENDENCIES_ERROR,
            payload: error,
          },
        ],
        [],
      );
    });
  });

  describe('fetchDependencies', () => {
    const dependenciesPackagerDescending = {
      ...mockDependenciesResponse,
      dependencies: sortBy(mockDependenciesResponse.dependencies, 'packager').reverse(),
    };

    let state;
    let mock;

    beforeEach(() => {
      state = getInitialState();
      state.endpoint = `${TEST_HOST}/dependencies`;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when endpoint is empty', () => {
      beforeEach(() => {
        state.endpoint = '';
      });

      it('does nothing', () => testAction(actions.fetchDependencies, undefined, state, [], []));
    });

    describe('on success', () => {
      describe('given only page param', () => {
        beforeEach(() => {
          state.pageInfo = { ...pageInfo };

          const paramsDefault = {
            sort_by: state.sortField,
            sort: state.sortOrder,
            page: state.pageInfo.page,
            filter: 'all',
          };

          mock
            .onGet(state.endpoint, { params: paramsDefault })
            .replyOnce(HTTP_STATUS_OK, mockDependenciesResponse, headers);
        });

        it('uses default sorting params from state', () =>
          testAction(
            actions.fetchDependencies,
            { page: state.pageInfo.page },
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({ data: mockDependenciesResponse, headers }),
              },
            ],
          ));
      });

      describe('with cursor pagination', () => {
        beforeEach(() => {
          state.pageInfo = {
            type: 'cursor',
            currentCursor: cursorHeaders['X-Page'],
            endCursor: cursorHeaders['X-Next-Page'],
            hasNextPage: true,
            hasPreviousPage: true,
            startCursor: cursorHeaders['X-Prev-Page'],
          };

          const expectedParams = {
            sort_by: state.sortField,
            sort: state.sortOrder,
            filter: 'all',
            cursor: state.pageInfo.currentCursor,
          };

          mock
            .onGet(state.endpoint, { params: expectedParams })
            .replyOnce(HTTP_STATUS_OK, mockDependenciesResponse, cursorHeaders);
        });

        it('fetches the results for the current cursor', () => {
          testAction(
            actions.fetchDependencies,
            { cursor: state.pageInfo.currentCursor },
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({
                  data: mockDependenciesResponse,
                  headers: cursorHeaders,
                }),
              },
            ],
          );
        });
      });

      describe('given params', () => {
        const paramsGiven = {
          sort_by: 'packager',
          sort: SORT_DESCENDING,
          page: 4,
          filter: 'all',
        };

        beforeEach(() => {
          mock
            .onGet(state.endpoint, { params: paramsGiven })
            .replyOnce(HTTP_STATUS_OK, dependenciesPackagerDescending, headers);
        });

        it('overrides default params', () =>
          testAction(
            actions.fetchDependencies,
            paramsGiven,
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({ data: dependenciesPackagerDescending, headers }),
              },
            ],
          ));
      });

      describe('given params with cursor', () => {
        const paramsGiven = {
          sort_by: 'packager',
          sort: SORT_DESCENDING,
          filter: 'all',
          cursor: 'eyJpZCI6IjQzIiwiX2tkIjoibiJ9Cg%2b%2b',
        };

        beforeEach(() => {
          mock
            .onGet(state.endpoint, { params: paramsGiven })
            .replyOnce(HTTP_STATUS_OK, dependenciesPackagerDescending, headers);
        });

        it('overrides default params', () =>
          testAction(
            actions.fetchDependencies,
            paramsGiven,
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({ data: dependenciesPackagerDescending, headers }),
              },
            ],
          ));
      });
    });

    describe.each`
      responseType                         | responseDetails                                                             | expectedErrorMessage
      ${'invalid response'}                | ${[HTTP_STATUS_OK, { foo: 'bar' }]}                                         | ${'Error fetching the dependency list. Please check your network connection and try again.'}
      ${'a response error'}                | ${[HTTP_STATUS_INTERNAL_SERVER_ERROR]}                                      | ${'Error fetching the dependency list. Please check your network connection and try again.'}
      ${'a response error with a message'} | ${[HTTP_STATUS_INTERNAL_SERVER_ERROR, { message: 'Custom error message' }]} | ${'Error fetching the dependency list: Custom error message'}
    `('given $responseType', ({ responseDetails, expectedErrorMessage }) => {
      beforeEach(() => {
        mock.onGet(state.endpoint).replyOnce(...responseDetails);
      });

      it('dispatches the receiveDependenciesError action and creates an alert', () =>
        testAction(
          actions.fetchDependencies,
          undefined,
          state,
          [],
          [
            {
              type: 'requestDependencies',
            },
            {
              type: 'receiveDependenciesError',
              payload: expect.any(Error),
            },
          ],
        ).then(() => {
          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: expectedErrorMessage,
          });
        }));
    });
  });

  describe('fetchExport', () => {
    let state;
    let mock;

    beforeEach(() => {
      state = getInitialState();
      state.exportEndpoint = `${TEST_HOST}/dependency_list_exports`;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when endpoint is empty', () => {
      beforeEach(() => {
        state.exportEndpoint = '';
      });

      it('does nothing', () => testAction(actions.fetchExport, undefined, state, [], []));
    });

    describe('on success', () => {
      beforeEach(() => {
        mock
          .onPost(state.exportEndpoint)
          .replyOnce(HTTP_STATUS_CREATED, mockResponseExportEndpoint);
      });

      it('shows loading spinner then creates alert for export email', () =>
        testAction(
          actions.fetchExport,
          { send_email: true },
          state,
          [
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: true,
            },
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: false,
            },
          ],
          [],
        ).then(() => {
          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: EXPORT_STARTED_MESSAGE,
            variant: VARIANT_INFO,
          });
        }));
    });

    describe('on success with status other than created (201)', () => {
      beforeEach(() => {
        mock.onPost(state.exportEndpoint).replyOnce(HTTP_STATUS_OK, mockResponseExportEndpoint);
      });

      it('shows alert with error', () =>
        testAction(
          actions.fetchExport,
          undefined,
          state,
          [
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: true,
            },
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: false,
            },
          ],
          [],
        ).then(() => {
          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: FETCH_EXPORT_ERROR_MESSAGE,
          });
        }));
    });

    describe('on failure', () => {
      beforeEach(() => {
        mock.onPost(state.exportEndpoint).replyOnce(HTTP_STATUS_NOT_FOUND);
      });

      it('shows alert with error', () =>
        testAction(
          actions.fetchExport,
          undefined,
          state,
          [
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: true,
            },
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: false,
            },
          ],
          [],
        ).then(() => {
          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: FETCH_EXPORT_ERROR_MESSAGE,
          });
        }));
    });
  });

  describe('setSortField', () => {
    it('commits the SET_SORT_FIELD mutation and dispatch the fetchDependencies action', () => {
      const field = 'packager';

      return testAction(
        actions.setSortField,
        field,
        getInitialState(),
        [
          {
            type: types.SET_SORT_FIELD,
            payload: field,
          },
        ],
        [],
      );
    });
  });

  describe('toggleSortOrder', () => {
    it('commits the TOGGLE_SORT_ORDER mutation and dispatch the fetchDependencies action', () =>
      testAction(
        actions.toggleSortOrder,
        undefined,
        getInitialState(),
        [
          {
            type: types.TOGGLE_SORT_ORDER,
          },
        ],
        [],
      ));
  });

  describe('setSearchFilterParameters', () => {
    it('takes an array of filter objects, generates a fetch-parameter object and commits it to SET_SEARCH_FILTER_PARAMETERS', () => {
      const filters = [
        {
          type: 'packager',
          value: { data: ['bundler'] },
        },
        {
          type: 'project',
          value: { data: ['GitLab', 'Gnome'] },
        },
        {
          type: 'component_version_ids',
          value: { data: ['1', '2'], operator: '=' },
        },
        // filters that contain strings (this happens when a user types in a value) should be ignored
        {
          type: 'ignored',
          value: { data: 'string_value' },
        },
      ];

      const expected = {
        project: ['GitLab', 'Gnome'],
        packager: ['bundler'],
        component_version_ids: ['1', '2'],
      };

      return testAction(
        actions.setSearchFilterParameters,
        filters,
        getInitialState(),
        [
          {
            type: types.SET_SEARCH_FILTER_PARAMETERS,
            payload: expected,
          },
        ],
        [],
      );
    });

    it('wraps the type with "not[...]" if the "!=" operator is used', () => {
      const filters = [
        {
          type: 'component_version_ids',
          value: { data: ['1', '2'], operator: '!=' },
        },
      ];

      const expected = {
        'not[component_version_ids]': ['1', '2'],
      };

      return testAction(
        actions.setSearchFilterParameters,
        filters,
        getInitialState(),
        [
          {
            type: types.SET_SEARCH_FILTER_PARAMETERS,
            payload: expected,
          },
        ],
        [],
      );
    });

    describe('with a license filter', () => {
      it('maps the given license names to their corresponding SPDX identifiers', () => {
        const initialStateWithLicenses = {
          ...getInitialState(),
          licenses: [
            { name: 'BSD Zero Clause License', spdxIdentifier: '0BSD' },
            { name: 'Apache 2.0', spdxIdentifier: 'Apache-2.0' },
          ],
        };

        const filters = [
          {
            type: 'licenses',
            value: { data: ['BSD Zero Clause License', 'Apache 2.0'] },
          },
        ];

        const expected = {
          licenses: ['0BSD', 'Apache-2.0'],
        };

        return testAction(
          actions.setSearchFilterParameters,
          filters,
          initialStateWithLicenses,
          [
            {
              type: types.SET_SEARCH_FILTER_PARAMETERS,
              payload: expected,
            },
          ],
          [],
        );
      });
    });
  });

  describe('fetchLicenses', () => {
    let mock;
    const licensesEndpoint = `${TEST_HOST}/licenses`;

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when the given endpoint is empty', () => {
      it('does nothing', () => {
        testAction(actions.fetchLicenses, undefined, getInitialState(), [], []);
      });
    });

    describe('on success', () => {
      it('correctly sets the loading state and the fetched licenses transformed to camelCased and an added id property', () => {
        const licenses = [
          {
            name: 'BSD Zero Clause License',
            spdx_Identifier: '0BSD',
            web_url: 'https://spdx.org/licenses/0BSD.html',
          },
        ];
        const camelCasedLicensesWithId = [
          {
            id: 0,
            name: 'BSD Zero Clause License',
            spdxIdentifier: '0BSD',
            webUrl: 'https://spdx.org/licenses/0BSD.html',
          },
        ];

        mock.onGet(licensesEndpoint).replyOnce(HTTP_STATUS_OK, { licenses });

        testAction(
          actions.fetchLicenses,
          licensesEndpoint,
          getInitialState(),
          [
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: true,
            },
            {
              type: types.SET_LICENSES,
              payload: camelCasedLicensesWithId,
            },
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: false,
            },
          ],
          [],
        );
      });
    });

    describe('on error', () => {
      it('creates an alert and sets the loading state to be "false"', async () => {
        mock.onGet(licensesEndpoint).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

        await testAction(
          actions.fetchLicenses,
          licensesEndpoint,
          getInitialState(),
          [
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: true,
            },
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: false,
            },
          ],
          [],
        );

        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: LICENSES_FETCH_ERROR_MESSAGE,
        });
      });
    });
  });

  describe('fetchVulnerabilities', () => {
    let mock;
    const dependenciesEndpoint = `${TEST_HOST}/vulnerabilities`;
    const item = { occurrenceId: 1 };

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when the given endpoint is empty', () => {
      it('does nothing', () => {
        testAction(
          actions.fetchVulnerabilities,
          { item: null, vulnerabilitiesEndpoint: null },
          getInitialState(),
          [],
          [],
        );
      });
    });

    describe('on success', () => {
      const payload = [{ occurrence_id: 1 }];

      it('correctly sets the loading item and the fetched vulnerabilities', async () => {
        mock.onGet(dependenciesEndpoint).replyOnce(HTTP_STATUS_OK, payload);

        await testAction(
          actions.fetchVulnerabilities,
          { item, vulnerabilitiesEndpoint: dependenciesEndpoint },
          getInitialState(),
          [
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
            {
              type: types.SET_VULNERABILITIES,
              payload,
            },
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
          ],
          [],
        );
      });
    });

    describe('on error', () => {
      it('creates an alert and sets vulnerability item to null', async () => {
        mock.onGet(dependenciesEndpoint).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

        await testAction(
          actions.fetchVulnerabilities,
          { item, vulnerabilitiesEndpoint: dependenciesEndpoint },
          getInitialState(),
          [
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
          ],
          [],
        );

        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: VULNERABILITIES_FETCH_ERROR_MESSAGE,
        });
      });
    });
  });

  describe('fetchDependenciesViaGraphQL', () => {
    let state;

    beforeEach(() => {
      state = getInitialState();
      state.fullPath = 'group/project';
      graphQLClient.query.mockClear();
      createAlert.mockClear();
    });

    describe('on success', () => {
      const expectedDependencies =
        mockGraphQLDependenciesResponse.data.namespace.dependencies.nodes.map(
          ({ packager, componentVersion, ...dependency }) => ({
            ...dependency,
            occurrenceId: 'extracted-from-get-id-from-graphql-id-util',
            componentId: 'extracted-from-get-id-from-graphql-id-util',
            // Note: This will be mapped to an actual value, once the field has been added to the GraphQL query
            // Related issue: https://gitlab.com/gitlab-org/gitlab/-/issues/532226
            projectCount: 1,
            version: componentVersion.version,
            packager: packager.toLowerCase(),
          }),
        );

      beforeEach(() => {
        graphQLClient.query.mockResolvedValue(mockGraphQLDependenciesResponse);
      });

      describe('sorting', () => {
        it.each`
          sortField     | sortOrder | expectedEnum
          ${'name'}     | ${'asc'}  | ${'NAME_ASC'}
          ${'name'}     | ${'desc'} | ${'NAME_DESC'}
          ${'packager'} | ${'asc'}  | ${'PACKAGER_ASC'}
          ${'packager'} | ${'desc'} | ${'PACKAGER_DESC'}
          ${'severity'} | ${'asc'}  | ${'SEVERITY_ASC'}
          ${'severity'} | ${'desc'} | ${'SEVERITY_DESC'}
          ${'license'}  | ${'asc'}  | ${'LICENSE_ASC'}
          ${'license'}  | ${'desc'} | ${'LICENSE_DESC'}
        `(
          'includes sort parameter in GraphQL variables when sortField is "$sortField" and sortOrder is "$sortOrder"',
          async ({ sortField, sortOrder, expectedEnum }) => {
            state.sortField = sortField;
            state.sortOrder = sortOrder;

            await testAction(
              actions.fetchDependenciesViaGraphQL,
              undefined,
              state,
              [
                {
                  type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                  payload: {
                    dependencies: expectedDependencies,
                    pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                  },
                },
              ],
              [{ type: 'requestDependencies' }],
            );

            const expectedVariables = {
              first: 20,
              fullPath: state.fullPath,
              sort: expectedEnum,
            };

            expect(graphQLClient.query).toHaveBeenCalledWith({
              query: projectDependencies,
              variables: expectedVariables,
            });
          },
        );

        it.each`
          sortField    | sortOrder
          ${undefined} | ${'asc'}
          ${'name'}    | ${undefined}
        `(
          'does not include sort parameter in GraphQL variables when sortField or sortOrder is undefined',
          async ({ sortField, sortOrder }) => {
            state.sortField = sortField;
            state.sortOrder = sortOrder;

            await testAction(
              actions.fetchDependenciesViaGraphQL,
              undefined,
              state,
              [
                {
                  type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                  payload: {
                    dependencies: expectedDependencies,
                    pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                  },
                },
              ],
              [{ type: 'requestDependencies' }],
            );

            const expectedVariables = {
              first: 20,
              fullPath: state.fullPath,
            };

            expect(graphQLClient.query).toHaveBeenCalledWith({
              query: projectDependencies,
              variables: expectedVariables,
            });
          },
        );
      });

      describe('filters', () => {
        it.each`
          scenario                                                                            | searchFilterParameters                               | expectedComponentNames
          ${'includes componentNames as a query variable when present'}                       | ${{ component_names: ['component1', 'component2'] }} | ${['component1', 'component2']}
          ${'does not include componentNames as a query variable when filter is empty'}       | ${{ component_names: [] }}                           | ${undefined}
          ${'does not include componentNames as a query variable when filter is not present'} | ${{}}                                                | ${undefined}
        `('$scenario', async ({ searchFilterParameters, expectedComponentNames }) => {
          state.searchFilterParameters = searchFilterParameters;

          await testAction(
            actions.fetchDependenciesViaGraphQL,
            undefined,
            state,
            [
              {
                type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                payload: {
                  dependencies: expectedDependencies,
                  pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                },
              },
            ],
            [{ type: 'requestDependencies' }],
          );

          const expectedVariables = {
            query: projectDependencies,
            variables: {
              first: 20,
              fullPath: state.fullPath,
              ...(expectedComponentNames && { componentNames: expectedComponentNames }),
            },
          };

          expect(graphQLClient.query).toHaveBeenCalledWith(expectedVariables);
        });
      });

      describe('pagination', () => {
        it('uses "first" query-parameter when no cursor is provided (initial page)', async () => {
          await testAction(
            actions.fetchDependenciesViaGraphQL,
            undefined,
            state,
            [
              {
                type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                payload: {
                  dependencies: expectedDependencies,
                  pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                },
              },
            ],
            [{ type: 'requestDependencies' }],
          );

          expect(graphQLClient.query).toHaveBeenCalledWith({
            query: projectDependencies,
            variables: {
              first: 20,
              fullPath: state.fullPath,
            },
          });
        });

        it('uses the group query when namespaceType is "group"', async () => {
          state.namespaceType = 'group';

          await testAction(
            actions.fetchDependenciesViaGraphQL,
            undefined,
            state,
            [
              {
                type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                payload: {
                  dependencies: expectedDependencies,
                  pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                },
              },
            ],
            [{ type: 'requestDependencies' }],
          );

          expect(graphQLClient.query).toHaveBeenCalledWith({
            query: groupDependencies,
            variables: {
              first: 20,
              fullPath: state.fullPath,
            },
          });
        });

        it('uses "after" query-parameter for forward navigation', async () => {
          const forwardCursor = 'eyJpZCI6IjQzIiwiX2tkIjoibiJ9';

          await testAction(
            actions.fetchDependenciesViaGraphQL,
            { cursor: forwardCursor },
            state,
            [
              {
                type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                payload: {
                  dependencies: expectedDependencies,
                  pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                },
              },
            ],
            [{ type: 'requestDependencies' }],
          );

          expect(graphQLClient.query).toHaveBeenCalledWith({
            query: projectDependencies,
            variables: {
              first: 20,
              after: forwardCursor,
              fullPath: state.fullPath,
            },
          });
        });

        it('uses "before" query-parameter for backward navigation', async () => {
          const backwardCursor = 'eyJpZCI6IjQyIiwiX2tkIjoicCJ9';

          state.pageInfo = {
            startCursor: backwardCursor,
            endCursor: 'eyJpZCI6IjYyIiwiX2tkIjoibiJ9',
            hasNextPage: true,
            hasPreviousPage: true,
          };

          await testAction(
            actions.fetchDependenciesViaGraphQL,
            { cursor: backwardCursor },
            state,
            [
              {
                type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                payload: {
                  dependencies: expectedDependencies,
                  pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                },
              },
            ],
            [{ type: 'requestDependencies' }],
          );

          expect(graphQLClient.query).toHaveBeenCalledWith({
            query: projectDependencies,
            variables: {
              last: 20,
              before: backwardCursor,
              fullPath: state.fullPath,
            },
          });
        });

        it('uses "first" query-parameter with custom page size when provided', async () => {
          const customPageSize = 50;

          await testAction(
            actions.fetchDependenciesViaGraphQL,
            { pageSize: customPageSize },
            state,
            [
              {
                type: types.RECEIVE_DEPENDENCIES_SUCCESS,
                payload: {
                  dependencies: expectedDependencies,
                  pageInfo: mockGraphQLDependenciesResponse.data.namespace.dependencies.pageInfo,
                },
              },
            ],
            [{ type: 'requestDependencies' }],
          );

          expect(graphQLClient.query).toHaveBeenCalledWith({
            query: projectDependencies,
            variables: {
              first: customPageSize,
              fullPath: state.fullPath,
            },
          });
        });
      });
    });

    describe('on error', () => {
      it.each(['custom error message', undefined])(
        'dispatches the receiveDependenciesError action and shows an alert',
        async (errorMessage) => {
          const error = new Error(errorMessage);
          graphQLClient.query.mockRejectedValue(error);

          expect(createAlert).not.toHaveBeenCalled();

          await testAction(
            actions.fetchDependenciesViaGraphQL,
            undefined,
            state,
            [],
            [{ type: 'requestDependencies' }, { type: 'receiveDependenciesError', payload: error }],
          );

          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: errorMessage || FETCH_ERROR_MESSAGE,
          });
        },
      );
    });
  });

  describe('fetchVulnerabilitiesViaGraphQL', () => {
    const item = { occurrenceId: '123' };
    const mockVulnerabilities = [
      { id: '1', name: 'Vulnerability 1', severity: 'HIGH', url: 'https://example.com/vuln/1' },
      { id: '2', name: 'Vulnerability 2', severity: 'MEDIUM', url: 'https://example.com/vuln/2' },
    ];
    const mockGraphQLResponse = {
      data: {
        dependency: {
          vulnerabilities: {
            nodes: mockVulnerabilities,
          },
        },
      },
    };

    describe('when occurrenceId is not provided', () => {
      it('does nothing', async () => {
        await testAction(
          actions.fetchVulnerabilitiesViaGraphQL,
          { item: {} },
          getInitialState(),
          [],
          [],
        );

        expect(graphQLClient.query).not.toHaveBeenCalled();
      });
    });

    describe('on success', () => {
      beforeEach(() => {
        graphQLClient.query.mockResolvedValue(mockGraphQLResponse);
      });

      it('commits TOGGLE_VULNERABILITY_ITEM_LOADING before and after the request', async () => {
        await testAction(
          actions.fetchVulnerabilitiesViaGraphQL,
          { item },
          getInitialState(),
          [
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
            {
              type: types.SET_VULNERABILITIES,
              payload: mockVulnerabilities.map((vulnerability) => ({
                ...vulnerability,
                occurrence_id: item.occurrenceId,
              })),
            },
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
          ],
          [],
        );
      });

      it('calls the GraphQL query with the correct query and variables', async () => {
        await testAction(
          actions.fetchVulnerabilitiesViaGraphQL,
          { item },
          getInitialState(),
          expect.any(Array),
          [],
        );

        expect(graphQLClient.query).toHaveBeenCalledWith({
          query: dependencyVulnerabilities,
          variables: {
            occurrenceId: 'extracted-from-convert-to-graphql-id-util',
          },
        });
      });

      it('adds `occurrence_id` to each vulnerability', async () => {
        await testAction(
          actions.fetchVulnerabilitiesViaGraphQL,
          { item },
          getInitialState(),
          [
            expect.any(Object),
            {
              type: types.SET_VULNERABILITIES,
              payload: mockVulnerabilities.map((vulnerability) => ({
                ...vulnerability,
                occurrence_id: item.occurrenceId,
              })),
            },
            expect.any(Object),
          ],
          [],
        );
      });

      it('handles vulnerabilities being null', async () => {
        graphQLClient.query.mockResolvedValue({
          data: {
            dependency: {
              vulnerabilities: {
                nodes: null,
              },
            },
          },
        });

        await testAction(
          actions.fetchVulnerabilitiesViaGraphQL,
          { item },
          getInitialState(),
          [
            expect.any(Object),
            {
              type: types.SET_VULNERABILITIES,
              payload: [],
            },
            expect.any(Object),
          ],
          [],
        );
      });
    });

    describe('on error', () => {
      beforeEach(() => {
        graphQLClient.query.mockRejectedValue(new Error('GraphQL error'));
      });

      it('shows an alert with error message and toggles the loading state', async () => {
        expect(createAlert).toHaveBeenCalledTimes(0);

        await testAction(
          actions.fetchVulnerabilitiesViaGraphQL,
          { item },
          getInitialState(),
          [
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
          ],
          [],
        );

        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: VULNERABILITIES_FETCH_ERROR_MESSAGE,
        });
      });
    });
  });
});
