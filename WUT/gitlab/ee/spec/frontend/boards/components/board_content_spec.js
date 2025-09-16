import { shallowMount } from '@vue/test-utils';
import EpicBoardContentSidebar from 'ee/boards/components/epic_board_content_sidebar.vue';
import BoardContent from '~/boards/components/board_content.vue';
import BoardContentSidebar from '~/boards/components/board_content_sidebar.vue';

describe('ee/BoardContent', () => {
  let wrapper;

  const createComponent = ({
    issuableType = 'issue',
    isIssueBoard = true,
    isEpicBoard = false,
    isSwimlanesOn = false,
  }) => {
    wrapper = shallowMount(BoardContent, {
      provide: {
        timeTrackingLimitToHours: false,
        canAdminList: false,
        canUpdate: false,
        labelsFilterBasePath: '',
        boardType: 'group',
        fullPath: 'gitlab-org/gitlab',
        issuableType,
        isIssueBoard,
        isEpicBoard,
        allowSubEpics: isEpicBoard ?? false,
        isGroupBoard: true,
        disabled: false,
        commentTemplatePaths: [],
      },
      propsData: {
        boardLists: {},
        boardId: 'gid://gitlab/Board/1',
        filterParams: {},
        isSwimlanesOn,
        listQueryVariables: {},
        addColumnFormVisible: false,
        useWorkItemDrawer: false,
      },
      stubs: {
        'board-content-sidebar': BoardContentSidebar,
        'epic-board-content-sidebar': EpicBoardContentSidebar,
      },
    });
  };

  beforeEach(() => {
    window.gon = { licensed_features: {} };
  });

  describe.each`
    isSwimlanesOn | isIssueBoard | isEpicBoard | resultIssue | resultEpic
    ${true}       | ${true}      | ${false}    | ${true}     | ${false}
    ${false}      | ${true}      | ${false}    | ${true}     | ${false}
    ${false}      | ${false}     | ${true}     | ${false}    | ${true}
  `(
    'with isSwimlanesOn=$isSwimlanesOn',
    ({ isSwimlanesOn, isIssueBoard, isEpicBoard, resultIssue, resultEpic }) => {
      beforeEach(() => {
        createComponent({ isIssueBoard, isEpicBoard, isSwimlanesOn });
      });

      it(`renders BoardContentSidebar = ${resultIssue}`, () => {
        expect(wrapper.findComponent(BoardContentSidebar).exists()).toBe(resultIssue);
      });

      it(`renders EpicBoardContentSidebar = ${resultEpic}`, () => {
        expect(wrapper.findComponent(EpicBoardContentSidebar).exists()).toBe(resultEpic);
      });
    },
  );
});
