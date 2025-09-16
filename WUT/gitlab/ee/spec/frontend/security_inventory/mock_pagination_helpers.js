import { subgroupsAndProjects } from './mock_data';

export const mockGroup = subgroupsAndProjects.data.group;

export const createGroupResponse = ({
  subgroups = mockGroup.descendantGroups.nodes || [],
  projects = mockGroup.projects.nodes || [],
  subgroupsPageInfo = { hasNextPage: false, endCursor: null },
  projectsPageInfo = { hasNextPage: false, endCursor: null },
} = {}) => ({
  data: {
    group: {
      ...mockGroup,
      descendantGroups: {
        nodes: subgroups,
        pageInfo: subgroupsPageInfo,
      },
      projects: {
        nodes: projects,
        pageInfo: projectsPageInfo,
      },
    },
  },
});

export const createPaginatedHandler = ({ first, second }) => {
  const handler = jest.fn();
  handler.mockResolvedValueOnce(createGroupResponse(first));
  handler.mockResolvedValueOnce(createGroupResponse(second));
  return handler;
};
