import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { observeElementOnce } from '~/lib/utils/dom_utils';
import StickyViewportFillerHeight from '~/diffs/components/sticky_viewport_filler_height.vue';

jest.mock('~/lib/utils/dom_utils');

describe('StickyViewportFillerHeight', () => {
  const initialViewportHeight = 800;
  const initialMinHeight = 300;

  let wrapper;
  let intersectionCallback;
  let rootObserverCallback;
  let parentObserverCallback;

  const createComponent = ({ minHeight = initialMinHeight, ...propsData } = {}) => {
    wrapper = shallowMount(StickyViewportFillerHeight, {
      propsData: {
        minHeight,
        ...propsData,
      },
      slots: { default: '<div id="slotContent"></div>' },
    });
  };

  const getSlotContent = () => wrapper.find('#slotContent');
  const getHeight = () => parseInt(wrapper.element.style.height, 10);

  const scroll = () => {
    window.dispatchEvent(new Event('scroll'));
  };
  const setViewportHeight = (height) => {
    window.innerHeight = height;
    window.dispatchEvent(new Event('resize'));
  };
  const resolveRootTop = (top) => {
    rootObserverCallback([{ boundingClientRect: { top } }]);
  };
  const resolveParentDimensions = (bottom, height) => {
    parentObserverCallback([{ boundingClientRect: { bottom, height } }]);
  };
  const show = () => {
    intersectionCallback([{ isIntersecting: true }]);
    return nextTick();
  };
  const hide = () => {
    intersectionCallback([{ isIntersecting: false }]);
    return nextTick();
  };
  const mockObserveElementOnce = () => {
    observeElementOnce.mockImplementation((element, callback) => {
      if (element === wrapper.element) {
        rootObserverCallback = callback;
      } else {
        parentObserverCallback = callback;
      }
    });
  };
  const mockIntersectionObserver = () => {
    jest.spyOn(window, 'IntersectionObserver').mockImplementation((callback) => {
      intersectionCallback = callback;
      return {
        observe: jest.fn(),
        disconnect: jest.fn(),
      };
    });
  };

  beforeEach(() => {
    setViewportHeight(initialViewportHeight);
    mockIntersectionObserver();
    mockObserveElementOnce();
  });

  it('renders default slot', () => {
    createComponent();
    expect(getSlotContent().exists()).toBe(true);
  });

  it('stops updates when hidden', async () => {
    createComponent();
    await show();
    resolveRootTop(0);
    resolveParentDimensions(
      initialViewportHeight + initialViewportHeight / 2,
      initialViewportHeight,
    );
    await nextTick();
    expect(getHeight()).toBe(initialViewportHeight);
    await hide();
    setViewportHeight(0);
    scroll();
    await nextTick();
    expect(getHeight()).toBe(initialViewportHeight);
    // call for root, call for parent
    expect(observeElementOnce).toHaveBeenCalledTimes(2);
  });

  it('handles non sticky position', async () => {
    createComponent();
    await show();
    const top = initialViewportHeight - initialViewportHeight / 2;
    resolveRootTop(top);
    resolveParentDimensions(
      initialViewportHeight + initialViewportHeight / 2,
      initialViewportHeight,
    );
    await nextTick();
    expect(getHeight()).toBe(initialViewportHeight - top);
  });

  describe('sticky', () => {
    it('handles sticky position', async () => {
      createComponent();
      await show();
      resolveRootTop(0);
      resolveParentDimensions(
        initialViewportHeight + initialViewportHeight / 2,
        initialViewportHeight,
      );
      await nextTick();
      expect(getHeight()).toBe(initialViewportHeight);
    });

    it('handles sticky position with top offset', async () => {
      const topOffset = 200;
      createComponent({ stickyTopOffset: topOffset });
      await show();
      resolveRootTop(topOffset);
      resolveParentDimensions(
        initialViewportHeight + initialViewportHeight / 2,
        initialViewportHeight,
      );
      await nextTick();
      expect(getHeight()).toBe(initialViewportHeight - topOffset);
    });

    it('handles sticky position with bottom offset', async () => {
      const bottomOffset = 200;
      createComponent({ stickyBottomOffset: bottomOffset });
      await show();
      resolveRootTop(0);
      resolveParentDimensions(
        initialViewportHeight + initialViewportHeight / 2,
        initialViewportHeight,
      );
      await nextTick();
      expect(getHeight()).toBe(initialViewportHeight - bottomOffset);
    });
  });

  describe('sticky bottom reached', () => {
    it('does not extend any more', async () => {
      const top = 200;
      const bottom = initialViewportHeight - 200;
      createComponent();
      await show();
      resolveRootTop(top);
      resolveParentDimensions(bottom, initialViewportHeight);
      await nextTick();
      expect(getHeight()).toBe(bottom - top);
    });

    it('ignores bottom offset', async () => {
      const top = 200;
      const bottom = initialViewportHeight - 200;
      const bottomOffset = 100;
      createComponent({ stickyBottomOffset: bottomOffset });
      await show();
      resolveRootTop(top);
      resolveParentDimensions(bottom, initialViewportHeight);
      await nextTick();
      expect(getHeight()).toBe(bottom - top);
    });
  });
});
