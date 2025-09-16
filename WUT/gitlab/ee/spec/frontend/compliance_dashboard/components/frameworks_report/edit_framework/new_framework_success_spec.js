import { GlPopover, GlButton, GlCard, GlSprintf, GlLink, GlBadge } from '@gitlab/ui';
import NewFrameworkSuccess from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/new_framework_success.vue';
import {
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  FEEDBACK_ISSUE_URL,
} from 'ee/compliance_dashboard/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('NewFrameworkSuccess', () => {
  let wrapper;
  const groupSecurityPoliciesPath = '/-/security/policies';
  const adherenceV2Enabled = true;
  const $router = {
    push: jest.fn(),
  };

  const findTitle = () => wrapper.find('h1');
  const findIllustration = () => wrapper.find('img');
  const findCtas = () => wrapper.findAllComponents(GlButton);
  const findPoliciesCard = () => wrapper.findByTestId('policies-card');
  const findProjectsCard = () => wrapper.findByTestId('projects-card');
  const findFeedbackBadge = () => wrapper.findComponent(GlBadge);
  const findPopover = () => wrapper.findComponent(GlPopover);

  const createComponent = (provideData = {}) => {
    return shallowMountExtended(NewFrameworkSuccess, {
      provide: {
        groupSecurityPoliciesPath,
        adherenceV2Enabled,
        ...provideData,
      },
      mocks: {
        $route: {
          query: { id: '123' },
        },
        $router,
      },
      stubs: {
        GlSprintf,
        GlCard,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });
  it('renders alt for the illustration', () => {
    expect(findIllustration().attributes('alt')).toBe('All todos done.');
  });

  it('displays the correct title', () => {
    expect(findTitle().text()).toBe('Compliance framework created!');
  });

  describe('CTAs', () => {
    it('renders Back to compliance center first', () => {
      expect(findCtas().at(0).text()).toBe('Back to compliance center');
    });

    it('navigates to compliance center when first CTA is clicked', () => {
      findCtas().at(0).vm.$emit('click');
      expect($router.push).toHaveBeenCalledWith({ name: ROUTE_FRAMEWORKS, query: { id: '123' } });
    });

    it('renders Edit framework second', () => {
      expect(findCtas().at(1).text()).toBe('Edit framework');
    });

    it('navigates to Edit form when second CTA is clicked', () => {
      findCtas().at(1).vm.$emit('click');
      expect($router.push).toHaveBeenCalledWith({
        name: ROUTE_EDIT_FRAMEWORK,
        params: { id: '123' },
      });
    });
  });

  it('renders two gl-card components', () => {
    expect(wrapper.findAllComponents(GlCard)).toHaveLength(2);
  });

  describe('policies card', () => {
    it('renders correct header', () => {
      expect(findPoliciesCard().find('h3').text()).toBe('Scope policies');
    });

    it('renders the correct link for security policies', () => {
      const policyLink = findPoliciesCard().findComponent(GlLink);
      expect(policyLink.attributes('href')).toBe('/-/security/policies');
    });
  });

  describe('projects card', () => {
    it('renders correct header', () => {
      expect(findProjectsCard().find('h3').text()).toBe('Apply to projects');
    });

    it('navigates to projects report when projects link is clicked', () => {
      const link = findProjectsCard().findComponent(GlLink);
      link.vm.$emit('click');
      expect($router.push).toHaveBeenCalledWith({ name: ROUTE_PROJECTS });
    });
  });

  describe('feedback label', () => {
    it('renders label when adherenceV2 is enabled', () => {
      expect(findFeedbackBadge().text()).toBe('Feedback?');
    });

    it('doesn not render feedback label when adherenceV2 is disabled', () => {
      wrapper = createComponent({ adherenceV2Enabled: false });
      expect(findFeedbackBadge().exists()).toBe(false);
    });

    it('uses the correct FEEDBACK_ISSUE_URL for feedback link', () => {
      expect(findPopover().findComponent(GlLink).attributes('href')).toBe(FEEDBACK_ISSUE_URL);
    });
  });
});
