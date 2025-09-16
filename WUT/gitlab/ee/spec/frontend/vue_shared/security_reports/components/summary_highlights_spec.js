import { GlSprintf } from '@gitlab/ui';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MR Widget Security Reports - Summary Highlights', () => {
  let wrapper;

  const createComponent = ({ highlights, showSingleSeverity, capped } = {}) => {
    wrapper = shallowMountExtended(SummaryHighlights, {
      propsData: {
        highlights,
        showSingleSeverity,
        capped,
      },
      stubs: { GlSprintf },
    });
  };

  it('should display the summary highlights properly', () => {
    createComponent({
      highlights: {
        critical: 10,
        high: 20,
        other: 60,
      },
    });

    expect(wrapper.html()).toMatchSnapshot();
  });

  describe.each`
    severity      | count
    ${'critical'} | ${5022}
    ${'high'}     | ${20}
    ${'other'}    | ${1}
  `('should only emphasize counts higher than 0 for $severity', ({ severity, count }) => {
    it('should emphasize counts higher than 0', () => {
      createComponent({
        highlights: {
          [severity]: count,
        },
      });

      expect(wrapper.findByTestId(severity).element.tagName).toBe('STRONG');
    });

    it('should use regular font for counts equal to 0', () => {
      createComponent({
        highlights: {
          [severity]: 0,
        },
      });

      expect(wrapper.findByTestId(severity).element.tagName).toBe('SPAN');
    });
  });

  it("calculate 'others' when other severities are provided", () => {
    const others = { medium: 50, low: 30, unknown: 20 };

    createComponent({
      highlights: {
        critical: 10,
        high: 20,
        ...others,
      },
    });

    expect(wrapper.text()).toContain('100 others');
  });

  it.each`
    severity      | color                   | count
    ${'critical'} | ${'gl-text-red-800'}    | ${10}
    ${'high'}     | ${'gl-text-red-600'}    | ${20}
    ${'medium'}   | ${'gl-text-orange-400'} | ${50}
    ${'low'}      | ${'gl-text-orange-300'} | ${30}
    ${'unknown'}  | ${'gl-text-gray-400'}   | ${20}
  `(
    "displays a number only when 'showSingleSeverity' property is provided",
    ({ severity, color, count }) => {
      const others = { medium: 50, low: 30, unknown: 20 };

      createComponent({
        showSingleSeverity: severity,
        highlights: {
          critical: 10,
          high: 20,
          ...others,
        },
      });

      expect(wrapper.html()).toContain(color);
      expect(wrapper.text().replace(/\s+/, ' ')).toBe(`${count.toString()} vulnerabilities`);
    },
  );

  it('shows capped results when capped property is true', () => {
    const others = { medium: 50, low: 1001, unknown: 20 };

    createComponent({
      capped: true,
      highlights: {
        critical: 1001,
        high: 20,
        ...others,
      },
    });

    expect(wrapper.text()).toContain('1000+ critical');
    expect(wrapper.text()).toContain('20 high');
    expect(wrapper.text()).toContain('1000+ others');
  });

  it('shows capped results when `other` is specified and capped property is true', () => {
    createComponent({
      capped: true,
      highlights: {
        critical: 1001,
        high: 20,
        other: 1001,
      },
    });

    expect(wrapper.text()).toContain('1000+ critical');
    expect(wrapper.text()).toContain('20 high');
    expect(wrapper.text()).toContain('1000+ others');
  });
});
