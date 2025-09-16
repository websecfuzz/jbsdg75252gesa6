import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { issueBoardListsQueryResponse } from 'jest/boards/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import BoardApp from '~/boards/components/board_app.vue';
import BoardContent from '~/boards/components/board_content.vue';
import epicBoardListsQuery from 'ee_component/boards/graphql/epic_board_lists.query.graphql';
import activeBoardItemQuery from 'ee_else_ce/boards/graphql/client/active_board_item.query.graphql';
import boardListsQuery from 'ee_else_ce/boards/graphql/board_lists.query.graphql';
import { rawIssue, epicBoardListsQueryResponse } from '../mock_data';

describe('BoardApp', () => {
  let wrapper;

  const boardListQueryHandler = jest.fn().mockResolvedValue(issueBoardListsQueryResponse);
  const epicBoardListQueryHandler = jest.fn().mockResolvedValue(epicBoardListsQueryResponse);
  const mockApollo = createMockApollo([
    [boardListsQuery, boardListQueryHandler],
    [epicBoardListsQuery, epicBoardListQueryHandler],
  ]);

  const findBoardContent = () => wrapper.findComponent(BoardContent);

  Vue.use(VueApollo);

  const createComponent = ({ issue = rawIssue, provide = {} } = {}) => {
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: activeBoardItemQuery,
      data: {
        activeBoardItem: { ...issue, listId: 'gid://gitlab/List/1' },
      },
    });

    wrapper = shallowMount(BoardApp, {
      apolloProvider: mockApollo,
      provide: {
        fullPath: 'gitlab-org',
        initialBoardId: 'gid://gitlab/Board/1',
        initialFilterParams: {},
        issuableType: 'issue',
        boardType: 'group',
        isIssueBoard: true,
        isGroupBoard: true,
        hasCustomFieldsFeature: true,
        ...provide,
      },
      stubs: ['router-view'],
    });
  };

  it.each`
    issuableType | isIssueBoard | isEpicBoard | queryHandler                 | notCalledHandler
    ${'epic'}    | ${false}     | ${true}     | ${epicBoardListQueryHandler} | ${boardListQueryHandler}
    ${'issue'}   | ${true}      | ${false}    | ${boardListQueryHandler}     | ${epicBoardListQueryHandler}
  `(
    'fetches $issuableType lists',
    ({ issuableType, isIssueBoard, isEpicBoard, queryHandler, notCalledHandler }) => {
      createComponent({
        provide: { issuableType, isEpicBoard, isIssueBoard },
      });

      expect(queryHandler).toHaveBeenCalled();
      expect(notCalledHandler).not.toHaveBeenCalled();
    },
  );

  describe('when on epic board', () => {
    describe('when `epicsListDrawer` feature is disabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isIssueBoard: false,
            issuableType: 'epic',
            glFeatures: { issuesListDrawer: true, epicsListDrawer: false },
          },
        });
      });

      it('passes `useWorkItemDrawer` as false', () => {
        expect(findBoardContent().props('useWorkItemDrawer')).toBe(false);
      });
    });

    describe('when issues when `issuesListDrawer` feature is enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isIssueBoard: false,
            issuableType: 'epic',
            glFeatures: { issuesListDrawer: false, epicsListDrawer: true },
          },
        });
      });

      it('passes `useWorkItemDrawer` as true', () => {
        expect(findBoardContent().props('useWorkItemDrawer')).toBe(true);
      });
    });
  });
});
