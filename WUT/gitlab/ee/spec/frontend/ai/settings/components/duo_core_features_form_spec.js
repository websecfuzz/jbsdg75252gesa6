import { GlLink, GlSprintf, GlFormGroup, GlFormCheckbox, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import DuoCoreFeaturesForm from 'ee/ai/settings/components/duo_core_features_form.vue';
import { DOCS_URL } from 'jh_else_ce/lib/utils/url_utility';

const requirementsPath = `${DOCS_URL}/subscriptions/subscription-add-ons#gitlab-duo-core`;
const mockTermsPath = `/handbook/legal/ai-functionality-terms/`;

describe('DuoCoreFeaturesForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    return shallowMountExtended(DuoCoreFeaturesForm, {
      propsData: {
        disabledCheckbox: false,
        duoCoreFeaturesEnabled: false,
        ...props,
      },
      provide: {
        isSaaS: true,
        ...provide,
      },
      stubs: {
        GlLink,
        GlSprintf,
        GlFormGroup,
        GlFormCheckbox,
      },
    });
  };

  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findButton = () => wrapper.find('button');
  const findIcon = () => wrapper.findComponent(GlIcon);

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the title', () => {
    expect(wrapper.text()).toMatch('Gitlab Duo Core');
  });

  it('renders the subtitle', () => {
    expect(wrapper.text()).toMatch(
      'When turned on, all billable users can access GitLab Duo Chat and Code Suggestions in supported IDEs.',
    );
  });

  it('renders the checkbox with correct label', () => {
    expect(findFormCheckbox().text()).toContain('Turn on IDE features');
  });

  it('sets initial checkbox state based on duoCoreFeaturesEnabled prop when unselected', () => {
    expect(findFormCheckbox().attributes('checked')).toBe(undefined);
  });

  it('emits change event when checkbox is clicked', () => {
    findFormCheckbox().vm.$emit('change');
    expect(wrapper.emitted('change')).toEqual([[false]]);
  });

  it('renders correct links', () => {
    expect(wrapper.findComponent(PromoPageLink).props('path')).toBe(mockTermsPath);
    expect(wrapper.findComponent(GlLink).props('href')).toBe(requirementsPath);
  });

  it('renders the description', () => {
    expect(wrapper.text()).toMatch(
      'By turning this on, you accept the GitLab AI Functionality Terms unless your organization has a separate agreement with GitLab governing AI feature usage. Check the eligibility requirements',
    );
  });

  describe('on SaaS', () => {
    beforeEach(() => {
      wrapper = createComponent({ provide: { isSaaS: true } });
    });

    it('renders the namespace description', () => {
      expect(wrapper.text()).toMatch('This setting applies to the whole top-level group.');
    });
  });

  describe('on Self-Managed', () => {
    beforeEach(() => {
      wrapper = createComponent({ provide: { isSaaS: false } });
    });

    it('renders the instance description', () => {
      expect(wrapper.text()).toMatch('This setting applies to the whole instance.');
    });
  });

  it('does not render icon and tooltip initially', () => {
    wrapper = createComponent();
    expect(findButton().exists()).toBe(false);
    expect(findIcon().exists()).toBe(false);
  });

  it('renders icon and tooltip after mounting', () => {
    wrapper = createComponent({ props: { disabledCheckbox: true } });

    expect(findButton().exists()).toBe(true);
    expect(findIcon().exists()).toBe(true);
  });

  it('leaves the checkbox enabled', () => {
    expect(findFormCheckbox().attributes('disabled')).not.toBeDefined();
  });

  describe('with Duo availability never on', () => {
    it('disables the checkbox', () => {
      wrapper = createComponent({ props: { disabledCheckbox: true } });

      expect(findFormCheckbox().attributes('disabled')).toBeDefined();
    });
  });

  it('disables checkbox switching from enabled to disabled', async () => {
    wrapper = createComponent({ props: { disabledCheckbox: false } });

    await wrapper.setProps({ disabledCheckbox: true });

    expect(findFormCheckbox().attributes('disabled')).toBeDefined();
  });
});
