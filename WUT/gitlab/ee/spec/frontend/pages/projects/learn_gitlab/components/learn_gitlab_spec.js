import { GlAlert } from '@gitlab/ui';
import { GlBreakpointInstance as bp } from '@gitlab/ui/dist/utils';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import Cookies from '~/lib/utils/cookies';
import { visitUrl } from '~/lib/utils/url_utility';
import CircularProgressBar from 'ee/pages/projects/learn_gitlab/components/circular_progress_bar/circular_progress_bar.vue';
import LearnGitlab from 'ee/pages/projects/learn_gitlab/components/learn_gitlab.vue';
import eventHub from '~/invite_members/event_hub';
import { INVITE_MODAL_OPEN_COOKIE } from 'ee/pages/projects/learn_gitlab/constants';
import { ON_CELEBRATION_TRACK_LABEL } from '~/invite_members/constants';
import eventHubNav from '~/super_sidebar/event_hub';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { testActions, testSections, testProject } from './mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('Learn GitLab', () => {
  let wrapper;

  const completionPercentage = 23;
  const findProgressBarBlock = () => wrapper.findByTestId('progress-bar-block');
  const findEndTutorialButton = () => wrapper.findByTestId('end-tutorial-button');

  const createWrapper = () => {
    wrapper = extendedWrapper(
      mount(LearnGitlab, {
        propsData: {
          actions: testActions,
          sections: testSections,
          project: testProject,
          learnGitlabEndPath: '/group/project/-/learn-gitlab/end',
        },
      }),
    );
  };

  describe('Initial rendering concerns', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders correctly', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    it('renders the progress bar label', () => {
      expect(findProgressBarBlock().text()).toContain('10 tasks to go');
    });

    it('renders the end tutorial button', () => {
      expect(findProgressBarBlock().text()).toContain('End tutorial');
    });

    it('renders the progress bar with correct percentage', () => {
      expect(wrapper.findComponent(CircularProgressBar).props('percentage')).toBe(
        completionPercentage,
      );
    });
  });

  describe('Circular Progress Bar', () => {
    it.each`
      breakpoint | classes
      ${'xs'}    | ${'gl-ml-5'}
      ${'sm'}    | ${'gl-ml-5'}
      ${'md'}    | ${'gl-ml-5'}
      ${'lg'}    | ${'gl-h-0 gl-mr-5 gl-ml-auto'}
      ${'xl'}    | ${'gl-h-0 gl-mr-5 gl-ml-auto'}
    `(
      'adds $classes to progress bar when breakpoint is $breakpoint',
      async ({ breakpoint, classes }) => {
        jest.spyOn(bp, 'getBreakpointSize').mockReturnValue(breakpoint);

        await createWrapper();

        expect(findProgressBarBlock().attributes('class')).toContain(classes);
      },
    );
  });

  describe('End tutorial button', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should disable the button when clicked', async () => {
      findEndTutorialButton().vm.$emit('click');

      await nextTick();

      expect(findEndTutorialButton().attributes('disabled')).toBeDefined();
    });

    it('should call visitUrl with the correct link when clicked', () => {
      findEndTutorialButton().vm.$emit('click');

      expect(visitUrl).toHaveBeenCalledWith('/group/project/-/learn-gitlab/end');
    });

    const { bindInternalEventDocument } = useMockInternalEventsTracking();
    it('should call trackEvent when clicked', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findEndTutorialButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_end_tutorial_button',
        {
          label: 'learn_gitlab',
          property: 'progress_percentage_on_end',
          value: completionPercentage,
        },
        undefined,
      );
    });
  });

  describe('Invite Members Modal', () => {
    let spy;
    let cookieSpy;

    beforeEach(() => {
      spy = jest.spyOn(eventHub, '$emit');
      cookieSpy = jest.spyOn(Cookies, 'remove');
    });

    afterEach(() => {
      Cookies.remove(INVITE_MODAL_OPEN_COOKIE);
    });

    it('emits openModal', () => {
      Cookies.set(INVITE_MODAL_OPEN_COOKIE, true);

      createWrapper();

      expect(spy).toHaveBeenCalledWith('openModal', {
        mode: 'celebrate',
        source: ON_CELEBRATION_TRACK_LABEL,
      });
      expect(cookieSpy).toHaveBeenCalledWith(INVITE_MODAL_OPEN_COOKIE);
    });

    it('does not emit openModal when cookie is not set', () => {
      createWrapper();

      expect(spy).not.toHaveBeenCalled();
      expect(cookieSpy).toHaveBeenCalledWith(INVITE_MODAL_OPEN_COOKIE);
    });
  });

  describe('when the showSuccessfulInvitationsAlert event is fired', () => {
    const findAlert = () => wrapper.findComponent(GlAlert);

    beforeEach(() => {
      createWrapper();
      eventHub.$emit('showSuccessfulInvitationsAlert');
    });

    it('displays the successful invitations alert', () => {
      expect(findAlert().exists()).toBe(true);
    });

    it('displays a message with the project name', () => {
      expect(findAlert().text()).toBe(
        "Your team is growing! You've successfully invited new team members to the test-project project.",
      );
    });
  });

  describe('with sidebar percentage updates', () => {
    let spy;

    beforeEach(() => {
      spy = jest.spyOn(eventHubNav, '$emit');
    });

    it('emits updatePillValue event for super sidebar', () => {
      createWrapper();

      eventHub.$emit('showSuccessfulInvitationsAlert');

      expect(spy).toHaveBeenCalledWith('updatePillValue', {
        value: `${completionPercentage}%`,
        itemId: 'learn_gitlab',
      });
    });
  });
});
