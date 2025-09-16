import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import component from 'ee/vue_shared/security_reports/components/dismissal_note.vue';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';

describe('dismissal note', () => {
  const now = new Date();
  const feedback = {
    author: {
      name: 'Tanuki',
      username: 'gitlab',
    },
    created_at: now.toString(),
  };
  const pipeline = {
    path: '/path-to-the-pipeline',
    id: 2,
  };
  const project = {
    value: 'Project one',
    url: '/path-to-the-project',
  };
  const dismissalReason = 'MITIGATING_CONTROL';
  let wrapper;

  const mountComponent = (options, mountFn = shallowMountExtended) => {
    wrapper = mountFn(component, { ...options, stubs: { GlSprintf } });
  };

  const findPipelineLink = () => wrapper.findByTestId('pipeline-link');
  const findProjectLink = () => wrapper.findByTestId('project-link');

  describe('with no attached project or pipeline', () => {
    beforeEach(() => {
      mountComponent({
        propsData: { feedback },
      });
    });

    it('should pass the author to the event item', () => {
      expect(wrapper.findComponent(EventItem).props('author')).toBe(feedback.author);
    });

    it('should pass the created date to the event item', () => {
      expect(wrapper.findComponent(EventItem).props('createdAt')).toBe(feedback.created_at);
    });

    it('should pass no action buttons', () => {
      expect(wrapper.findComponent(EventItem).props('showActionButtons')).toBe(false);
    });

    it('should return the event text with no project data', () => {
      expect(wrapper.text()).toBe('Dismissed');
    });

    it('should return the event text with dismissal reason', () => {
      mountComponent({
        propsData: { feedback: { ...feedback, dismissalReason } },
      });

      expect(wrapper.text()).toMatchInterpolatedText('Dismissed: Mitigating control');
    });
  });

  describe('with an attached project', () => {
    beforeEach(() => {
      mountComponent({
        propsData: { feedback, project },
      });
    });

    it('should link to the project', () => {
      expect(findProjectLink().attributes('href')).toBe(project.url);
    });

    it('should return the event text with project data', () => {
      expect(wrapper.text()).toMatchInterpolatedText(`Dismissed at ${project.value}`);
    });

    it('should return the event text with dismissal reason', () => {
      mountComponent({
        propsData: { project, feedback: { ...feedback, dismissalReason } },
      });

      expect(wrapper.text()).toMatchInterpolatedText(
        `Dismissed: Mitigating control at ${project.value}`,
      );
    });

    it('should pass edit dismissal action button', () => {
      expect(wrapper.findComponent(EventItem).props('actionButtons')).toMatchObject([
        { iconName: 'pencil', title: 'Edit dismissal' },
      ]);
    });
  });

  describe('with an attached pipeline', () => {
    beforeEach(() => {
      mountComponent({
        propsData: { feedback: { ...feedback, pipeline } },
      });
    });

    it('should link to the pipeline', () => {
      expect(findPipelineLink().attributes('href')).toBe(pipeline.path);
    });

    it('should return the event text with project data', () => {
      expect(wrapper.text()).toMatchInterpolatedText(`Dismissed on pipeline #${pipeline.id}`);
    });

    it('should return the event text with dismissal reason', () => {
      mountComponent({
        propsData: { feedback: { ...feedback, pipeline, dismissalReason } },
      });

      expect(wrapper.text()).toMatchInterpolatedText(
        `Dismissed: Mitigating control on pipeline #${pipeline.id}`,
      );
    });
  });

  describe('with an attached pipeline and project', () => {
    beforeEach(() => {
      mountComponent({
        propsData: { feedback: { ...feedback, pipeline }, project },
      });
    });

    it('should link to the pipeline', () => {
      expect(findPipelineLink().attributes('href')).toBe(pipeline.path);
    });

    it('should link to the project', () => {
      expect(findProjectLink().attributes('href')).toBe(project.url);
    });

    it('should return the event text with project data', () => {
      expect(wrapper.text()).toMatchInterpolatedText(
        `Dismissed on pipeline #${pipeline.id} at ${project.value}`,
      );
    });

    it('should return the event text with dismissal reason', () => {
      mountComponent({
        propsData: { project, feedback: { ...feedback, pipeline, dismissalReason } },
      });

      expect(wrapper.text()).toMatchInterpolatedText(
        `Dismissed: Mitigating control on pipeline #${pipeline.id} at ${project.value}`,
      );
    });
  });

  describe('with unsafe data', () => {
    const unsafeProject = {
      ...project,
      value: 'Foo <script>alert("XSS")</script>',
    };

    beforeEach(() => {
      mountComponent({
        propsData: {
          feedback,
          project: unsafeProject,
        },
      });
    });

    it('should escape the project name', () => {
      // wrapper.text() is the text string, if the tag was parsed then it would be missing <script> from the string.
      expect(wrapper.text()).toContain(unsafeProject.value);
    });
  });

  describe('with a comment', () => {
    const commentDetails = {
      comment: 'How many times have I said we need locking mechanisms on the vehicle doors!',
      comment_timestamp: now.toString(),
      comment_author: {
        name: 'Muldoon',
        username: 'RMuldoon62',
      },
    };
    let commentItem;

    beforeEach(() => {
      mountComponent({
        propsData: {
          feedback: {
            ...feedback,
            comment_details: commentDetails,
          },
          project,
        },
      });
      commentItem = wrapper.findAllComponents(EventItem).at(1);
    });

    it('should render the comment', () => {
      expect(commentItem.text()).toBe(commentDetails.comment);
    });

    it('should render the comment author', () => {
      expect(commentItem.props().author).toBe(commentDetails.comment_author);
    });

    it('should render the comment timestamp', () => {
      expect(commentItem.props().createdAt).toBe(commentDetails.comment_timestamp);
    });

    it('should pass action buttons', () => {
      expect(commentItem.props('actionButtons')).toMatchObject([
        { iconName: 'pencil', title: 'Edit dismissal' },
      ]);
    });
  });
});
