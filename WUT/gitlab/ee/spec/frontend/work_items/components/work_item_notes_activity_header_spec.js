import AiSummarizeNotes from 'ee_component/notes/components/note_actions/ai_summarize_notes.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemNotesActivityHeader from '~/work_items/components/notes/work_item_notes_activity_header.vue';

describe('WorkItemNotesActivityHeader component', () => {
  let wrapper;

  const findAiSummarizeNotes = () => wrapper.findComponent(AiSummarizeNotes);

  const createComponent = ({ canSummarizeComments = false } = {}) => {
    wrapper = shallowMountExtended(WorkItemNotesActivityHeader, {
      propsData: {
        canSummarizeComments,
        disableActivityFilterSort: false,
        workItemId: 'gid://gitlab/WorkItem/123',
        workItemType: 'Task',
      },
    });
  };

  it.each([true, false])(
    'renders "View summary" button depending on canSummarizeComments',
    async (canSummarizeComments) => {
      createComponent({ canSummarizeComments });
      await waitForPromises();

      expect(findAiSummarizeNotes().exists()).toBe(canSummarizeComments);
    },
  );
});
