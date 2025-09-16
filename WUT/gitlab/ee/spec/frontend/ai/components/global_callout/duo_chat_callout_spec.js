import { shallowMount } from '@vue/test-utils';
import { GlPopover, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import DuoChatCallout, {
  ASK_DUO_HOTSPOT_CSS_CLASS,
  DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS,
} from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { stubExperiments } from 'helpers/experimentation_helper';

describe('DuoChatCallout', () => {
  let wrapper;
  let userCalloutDismissSpy;
  let trackingSpy;

  const findCalloutDismisser = () => wrapper.findComponent(UserCalloutDismisser);
  const findPopoverWithinDismisser = () => findCalloutDismisser().findComponent(GlPopover);
  const findLinkWithinDismisser = () => findCalloutDismisser().findComponent(GlButton);
  const findLearnHowLink = () => wrapper.findComponent(GlLink);
  const findHotspot = () => document.querySelector(`.${ASK_DUO_HOTSPOT_CSS_CLASS}`);

  const findTargetElements = () =>
    document.querySelectorAll(`.${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}`);
  const findFirstTargetElement = () => findTargetElements()[0];
  const findParagraphWithinPopover = () =>
    wrapper.find('[data-testid="duo-chat-callout-description"]');

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ shouldShowCallout = true } = {}) => {
    userCalloutDismissSpy = jest.fn();
    wrapper = shallowMount(DuoChatCallout, {
      directives: {
        Outside: createMockDirective('outside'),
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    setHTMLFixture(`
      <button class="${ASK_DUO_HOTSPOT_CSS_CLASS}"></button>
      <button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}"></button>
    `);

    createComponent();
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('renders the UserCalloutDismisser component', () => {
    expect(findCalloutDismisser().exists()).toBe(true);
    expect(findCalloutDismisser().props('featureName')).toBe('duo_chat_callout');
  });

  it('renders core elements as part of the dismisser', () => {
    expect(findPopoverWithinDismisser().exists()).toBe(true);
    expect(findLinkWithinDismisser().exists()).toBe(true);
  });

  it('renders the correct texts and link', () => {
    expect(findPopoverWithinDismisser().text()).toContain('AI features are now available');
    expect(findPopoverWithinDismisser().text()).toContain(
      'You can also use Chat in GitLab. Ask questions about:',
    );
    expect(findLearnHowLink().attributes('href')).toBe('/help/user/gitlab_duo/_index');
    expect(findLearnHowLink().text()).toBe('Learn how');
    expect(findLinkWithinDismisser().text()).toBe('Ask GitLab Duo');
  });

  it('does not render the core elements if the callout is dismissed', () => {
    createComponent({ shouldShowCallout: false });
    expect(findPopoverWithinDismisser().exists()).toBe(false);
    expect(findLinkWithinDismisser().exists()).toBe(false);
  });

  it('does not throw if the popoverTarget button does not exist', () => {
    setHTMLFixture(`<button></button>`);
    expect(() => createComponent()).not.toThrow();
    expect(findFirstTargetElement()).toBeUndefined();
    expect(wrapper.text()).toBe('');
  });

  describe('popover props', () => {
    it('passes the correct target to the popover when there is only one potential target element', () => {
      const el = findFirstTargetElement();
      expect(findPopoverWithinDismisser().props('target')).toEqual(el);
    });

    it('passes the correct target to the popover when there are several potentiaL target elements', () => {
      setHTMLFixture(`
        <button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}" style="display: none"></button>
        <button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}" style="visibility: hidden"></button>
        <button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}"></button>
      `);
      const expectedElement = findTargetElements()[2];
      createComponent();
      expect(findPopoverWithinDismisser().props('target')).toEqual(expectedElement);
    });

    it('passes the correct triggers', () => {
      expect(findPopoverWithinDismisser().props('triggers')).toEqual('manual');
    });
  });

  describe('interaction', () => {
    it("dismisses the callout when the popover's close button is clicked, but doesn't open the chat", () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      findPopoverWithinDismisser().vm.$emit('close-button-clicked');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
    });

    it("doesn't dismiss the callout and doesn't open the chat when user clicks within the callout", async () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      await findParagraphWithinPopover().trigger('click');

      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
    });

    it('dismisses the callout and opens the chat when the chat button is clicked', () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
      findFirstTargetElement().click();
      expect(userCalloutDismissSpy).toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeDefined();
    });

    it('dismisses the callout and opens the chat when the popover button is clicked', () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
      findLinkWithinDismisser().vm.$emit('click');
      expect(userCalloutDismissSpy).toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeDefined();
    });

    it('does not try to dismiss the callout if the button is clicked after the callout is already dismissed', () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      findPopoverWithinDismisser().vm.$emit('close-button-clicked');
      expect(userCalloutDismissSpy).toHaveBeenCalledTimes(1);
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      findFirstTargetElement().click();
      expect(userCalloutDismissSpy).toHaveBeenCalledTimes(1);
    });

    it('does not fail if the chat button is clicked after callout was dismissed', () => {
      createComponent({ shouldShowCallout: false });
      expect(() => findFirstTargetElement().click()).not.toThrow();
    });
  });

  describe('with tracking', () => {
    beforeEach(() => {
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    afterEach(() => {
      unmockTracking();
    });

    it('tracks render', () => {
      findPopoverWithinDismisser().vm.$emit('shown');

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'render_duo_chat_callout', {});
    });

    it('does not track render when callout is not shown', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).not.toHaveBeenCalled();
    });

    it('tracks click learn how link', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findLearnHowLink().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_learn_how_link_duo_chat_callout',
        {},
        undefined,
      );
    });

    it('tracks duo chat button click', () => {
      findFirstTargetElement().click();

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
        label: 'tanuki_bot_breadcrumbs_button',
      });
    });

    it('tracks dismiss', () => {
      findPopoverWithinDismisser().vm.$emit('close-button-clicked');

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'dismiss_duo_chat_callout', {});
    });

    it('tracks popover button click', () => {
      findLinkWithinDismisser().vm.$emit('click');

      expect(trackingSpy).not.toHaveBeenCalledWith(undefined, 'dismiss_duo_chat_callout', {});
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_ask_gitlab_duo', {});
    });
  });

  describe('beforeDestroy', () => {
    it('removes event listeners', () => {
      const removeTargetSpy = jest.spyOn(findFirstTargetElement(), 'removeEventListener');

      wrapper.destroy();

      expect(removeTargetSpy).toHaveBeenCalledWith('click', expect.any(Function));
    });
  });

  describe('when hotspot_duo_chat_during_trial experiment', () => {
    beforeEach(() => {
      stubExperiments({ hotspot_duo_chat_during_trial: 'candidate' });
      createComponent();
    });

    it('passes the correct target', () => {
      const el = findHotspot();
      expect(findPopoverWithinDismisser().props('target')).toEqual(el);
    });

    it('passes the correct triggers', () => {
      expect(findPopoverWithinDismisser().props('triggers')).toEqual('hover focus');
    });

    it('does not show popover', () => {
      expect(findPopoverWithinDismisser().props('show')).toBe(false);
    });

    describe('with tracking', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      it('tracks hotspot render', () => {
        createComponent();

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'render_ask_gitlab_duo_hotspot', {
          context: expect.any(Object),
        });
      });

      it('tracks hotspot click', () => {
        findHotspot().click();

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_ask_gitlab_duo_hotspot', {
          context: expect.any(Object),
        });
      });

      it('tracks duo chat button click', () => {
        findFirstTargetElement().click();

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_button', {
          label: 'tanuki_bot_breadcrumbs_button',
          context: expect.any(Object),
        });
      });
    });

    describe('beforeDestroy', () => {
      it('removes event listeners', () => {
        const removeHotspotSpy = jest.spyOn(findHotspot(), 'removeEventListener');
        const removeTargetSpy = jest.spyOn(findFirstTargetElement(), 'removeEventListener');

        wrapper.destroy();

        expect(removeHotspotSpy).toHaveBeenCalledWith('click', expect.any(Function));
        expect(removeTargetSpy).toHaveBeenCalledWith('click', expect.any(Function));
      });
    });
  });
});
