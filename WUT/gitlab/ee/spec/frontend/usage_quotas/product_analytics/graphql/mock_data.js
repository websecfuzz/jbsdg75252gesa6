import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';

export const getProjectUsage = ({ id, name, usage } = {}) => ({
  id: id || convertToGraphQLId(TYPENAME_PROJECT, 1),
  name: name || 'some project',
  productAnalyticsEventsStored: usage || [],
  webUrl: `/${name}`,
  avatarUrl: `/${name}.jpg`,
  __typename: 'Project',
});

export const getProjectsUsageDataResponse = (projects) => ({
  group: {
    id: convertToGraphQLId(TYPENAME_GROUP, 1),
    productAnalyticsStoredEventsLimit: 1000000,
    projects: {
      nodes: projects || [
        getProjectUsage({
          id: convertToGraphQLId(TYPENAME_PROJECT, 1),
          name: 'some onboarded project',
          usage: [
            {
              year: 2023,
              month: 11,
              count: 1234,
            },
          ],
        }),
        getProjectUsage({
          id: convertToGraphQLId(TYPENAME_PROJECT, 2),
          name: 'not onboarded project',
          usage: [
            {
              year: 2023,
              month: 11,
              count: null,
            },
          ],
        }),
      ],
      __typename: 'ProjectConnection',
    },
    __typename: 'Group',
  },
});

export const getProjectWithYearsUsage = ({ id, name } = {}) =>
  getProjectUsage({
    id,
    name,
    usage: [
      {
        month: 1,
        year: 2023,
        count: 1,
      },
      {
        month: 12,
        year: 2022,
        count: 1,
      },
      {
        month: 11,
        year: 2022,
        count: 1,
      },
      {
        month: 10,
        year: 2022,
        count: 1,
      },
      {
        month: 9,
        year: 2022,
        count: 1,
      },
      {
        month: 8,
        year: 2022,
        count: 1,
      },
      {
        month: 7,
        year: 2022,
        count: 1,
      },
      {
        month: 6,
        year: 2022,
        count: 1,
      },
      {
        month: 5,
        year: 2022,
        count: 1,
      },
      {
        month: 4,
        year: 2022,
        count: 1,
      },
      {
        month: 3,
        year: 2022,
        count: 1,
      },
      {
        month: 2,
        year: 2022,
        count: 1,
      },
    ],
  });
