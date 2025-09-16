import { GlProgressBar, GlCard, GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GetStarted from 'ee/pages/projects/get_started/components/get_started.vue';
import SectionHeader from 'ee/pages/projects/get_started/components/section_header.vue';
import SectionBody from 'ee/pages/projects/get_started/components/section_body.vue';
import eventHub from '~/invite_members/event_hub';
import eventHubNav from '~/super_sidebar/event_hub';
import DuoExtensions from 'ee/pages/projects/get_started/components/duo_extensions.vue';
import RightSidebar from 'ee/pages/projects/get_started/components/right_sidebar.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { visitUrl } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('GetStarted', () => {
  let wrapper;

  const createSections = () => [
    {
      title: 'Section 1',
      description: 'Description 1',
      actions: [
        { id: 1, title: 'Action 1', completed: true },
        { id: 2, title: 'Action 2', completed: false },
      ],
    },
    {
      title: 'Section 2',
      description: 'Description 2',
      trialActions: [
        { id: 3, title: 'Trial Action 1', completed: true },
        { id: 4, title: 'Trial Action 2', completed: false },
      ],
    },
  ];

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GetStarted, {
      propsData: {
        sections: createSections(),
        tutorialEndPath: '/group/project/-/get-started/end',
        ...props,
      },
      stubs: {
        GlCard: { template: '<div><slot name="header" /><slot /></div>' },
      },
    });
  };

  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findCards = () => wrapper.findAllComponents(GlCard);
  const findSectionHeaders = () => wrapper.findAllComponents(SectionHeader);
  const findSectionBodies = () => wrapper.findAllComponents(SectionBody);
  const findTitle = () => wrapper.find('h2');
  const findSuccessfulInvitationsAlert = () => wrapper.findComponent(GlAlert);
  const findRightSidebar = () => wrapper.findComponent(RightSidebar);
  const findEndTutorialButton = () => wrapper.findByTestId('end-tutorial-button');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('renders the correct title', () => {
      expect(findTitle().text()).toBe('Quick start');
    });

    it('renders a progress bar', () => {
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders a card for each section', () => {
      expect(findCards()).toHaveLength(2);
    });

    it('renders section headers', () => {
      expect(findSectionHeaders()).toHaveLength(2);
    });

    it('renders section bodies', () => {
      expect(findSectionBodies()).toHaveLength(2);
    });

    it('renders the right sidebar', () => {
      expect(findRightSidebar().exists()).toBe(true);
    });
  });

  describe('action counting', () => {
    it('correctly calculates total actions', () => {
      createComponent();
      expect(wrapper.vm.totalActions).toBe(4);
    });

    it('correctly calculates completed actions', () => {
      createComponent();
      expect(wrapper.vm.completedActions).toBe(2);
    });

    it('correctly calculates completion percentage', () => {
      createComponent();
      expect(wrapper.vm.completionPercentage).toBe(50);
    });

    it('handles sections without actions or trialActions', () => {
      createComponent({
        sections: [{ title: 'Empty Section', description: 'No actions' }],
      });
      expect(wrapper.vm.totalActions).toBe(0);
      expect(wrapper.vm.completedActions).toBe(0);
    });
  });

  describe('section expansion', () => {
    beforeEach(() => {
      createComponent();
    });

    it('expands the first section by default', () => {
      expect(wrapper.vm.expandedIndex).toBe(0);
      expect(wrapper.vm.isExpanded(0)).toBe(true);
      expect(wrapper.vm.isExpanded(1)).toBe(false);
    });

    it('toggles expansion when a section header is clicked', async () => {
      // Toggle section 1 (should collapse it)
      await wrapper.vm.toggleExpand(0);
      expect(wrapper.vm.expandedIndex).toBe(null);
      expect(wrapper.vm.isExpanded(0)).toBe(false);

      // Toggle section 2 (should expand it)
      await wrapper.vm.toggleExpand(1);
      expect(wrapper.vm.expandedIndex).toBe(1);
      expect(wrapper.vm.isExpanded(0)).toBe(false);
      expect(wrapper.vm.isExpanded(1)).toBe(true);

      // Toggle section 2 again (should collapse it)
      await wrapper.vm.toggleExpand(1);
      expect(wrapper.vm.expandedIndex).toBe(null);
      expect(wrapper.vm.isExpanded(1)).toBe(false);
    });

    it('renders the duo extension section', () => {
      expect(wrapper.findComponent(DuoExtensions).exists()).toBe(true);
    });
  });

  describe('End tutorial button', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should disable the button when clicked', async () => {
      findEndTutorialButton().vm.$emit('click');

      await nextTick();

      expect(findEndTutorialButton().attributes('disabled')).toBeDefined();
    });

    it('should call visitUrl with the correct link when clicked', () => {
      findEndTutorialButton().vm.$emit('click');

      expect(visitUrl).toHaveBeenCalledWith('/group/project/-/get-started/end');
    });

    const { bindInternalEventDocument } = useMockInternalEventsTracking();
    it('should call trackEvent when clicked', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findEndTutorialButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_end_tutorial_button',
        {
          label: 'get_started',
          property: 'progress_percentage_on_end',
          value: 50,
        },
        undefined,
      );
    });
  });

  describe('event handling and action completion', () => {
    let sections;

    beforeEach(() => {
      jest.spyOn(eventHub, '$on');
      jest.spyOn(eventHub, '$off');
      jest.spyOn(eventHubNav, '$emit');
      sections = createSections();
      sections[0].actions[1].urlType = 'invite';
      createComponent({ sections });
    });

    it('registers event listeners on mount', () => {
      expect(eventHub.$on).toHaveBeenCalledWith(
        'showSuccessfulInvitationsAlert',
        wrapper.vm.handleShowSuccessfulInvitationsAlert,
      );
    });

    it('removes event listeners before destroy', () => {
      wrapper.destroy();

      expect(eventHub.$off).toHaveBeenCalledWith(
        'showSuccessfulInvitationsAlert',
        wrapper.vm.handleShowSuccessfulInvitationsAlert,
      );
    });

    it('marks an action as completed by ID', async () => {
      expect(findProgressBar().props('value')).toBe(50);

      // Mark action with ID 2 as completed
      eventHub.$emit('showSuccessfulInvitationsAlert');
      await nextTick();

      expect(findProgressBar().props('value')).toBe(75);

      // Assert that the sidebar percentage was updated
      expect(eventHubNav.$emit).toHaveBeenCalledWith('updatePillValue', {
        value: '75%',
        itemId: 'get_started',
      });
    });
  });

  describe('invitation alerts', () => {
    let sections;

    beforeEach(() => {
      sections = createSections();
      sections[0].actions[0].urlType = 'invite';
      createComponent({ sections });
    });

    it('does not show alert by default', () => {
      expect(findSuccessfulInvitationsAlert().exists()).toBe(false);
    });

    it('shows alert when invitation is successful', async () => {
      eventHub.$emit('showSuccessfulInvitationsAlert');
      await nextTick();

      expect(findSuccessfulInvitationsAlert().exists()).toBe(true);
      expect(findSuccessfulInvitationsAlert().props('variant')).toBe('success');
      expect(findSuccessfulInvitationsAlert().props('dismissible')).toBe(true);
    });

    it('dismisses the alert when dismissed', async () => {
      eventHub.$emit('showSuccessfulInvitationsAlert');
      await nextTick();

      findSuccessfulInvitationsAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findSuccessfulInvitationsAlert().exists()).toBe(false);
    });
  });
});
