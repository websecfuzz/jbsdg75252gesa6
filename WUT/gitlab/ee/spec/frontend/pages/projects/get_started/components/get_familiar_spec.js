import { GlCard, GlButton, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GetFamiliar from 'ee/pages/projects/get_started/components/get_familiar.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('Get Familiar component', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(GetFamiliar);
  });

  it('renders correctly', () => {
    expect(wrapper.element).toMatchSnapshot();
  });

  // Fix for the existing test - heading is in h2, not GlLink
  it('shows Get Familiar heading', () => {
    expect(wrapper.find('h2').text()).toBe('Get familiar with GitLab Duo');
  });

  it('shows the correct description text', () => {
    expect(wrapper.find('p.gl-text-subtle').text()).toBe(
      'Explore these resources to learn essential features and best practices.',
    );
  });

  it('renders the GitLab Duo Code Suggestions card', () => {
    const card = wrapper.findComponent(GlCard);
    expect(card.exists()).toBe(true);
    expect(card.attributes('data-testid')).toBe('duo-code-suggestions-card');
    expect(card.text()).toContain('GitLab Duo Code Suggestions');
  });

  it('displays all four feature list items', () => {
    const listItems = wrapper.findAll('ul li');
    expect(listItems).toHaveLength(4);

    expect(listItems.at(0).text()).toContain('Code completion:');
    expect(listItems.at(1).text()).toContain('Code generation:');
    expect(listItems.at(2).text()).toContain('Context-aware suggestions:');
    expect(listItems.at(3).text()).toContain('Support for multiple languages:');
  });

  it('displays the features list with correct accessibility label', () => {
    const featuresList = wrapper.find('ul');
    expect(featuresList.attributes('aria-label')).toBe('GitLab Duo code features');
  });

  it('renders walkthrough button with correct text and URL', () => {
    const button = wrapper.findComponent(GlButton);
    expect(button.exists()).toBe(true);
    expect(button.text()).toContain('Try walkthrough');
    expect(button.attributes('data-testid')).toBe('walkthrough-link');
    expect(button.attributes('aria-label')).toBe('Try the walkthrough in a new tab');

    expect(button.attributes('href')).toBe(
      'https://gitlab.navattic.com/gitlab-with-duo-get-started-page',
    );

    expect(button.props('category')).toBe('tertiary');
  });

  it('renders external link icon in the walkthrough button', () => {
    const icon = wrapper.findComponent(GlIcon);
    expect(icon.exists()).toBe(true);
    expect(icon.props('name')).toBe('external-link');
    expect(icon.props('size')).toBe(16);
    expect(icon.classes()).toContain('gl-ml-2');
  });

  describe('with tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks click on try walkthrough link', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await wrapper.findByTestId('walkthrough-link').vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_duo_try_walkthrough_in_get_started',
        {},
        undefined,
      );
    });
  });
});
