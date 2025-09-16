import { GlSingleStat } from '@gitlab/ui/dist/charts';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SingleStat from 'ee/analytics/analytics_dashboards/components/visualizations/single_stat.vue';

describe('Single Stat Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findSingleStat = () => wrapper.findComponent(GlSingleStat);

  const createWrapper = (props = {}) => {
    wrapper = mountExtended(SingleStat, {
      propsData: {
        data: props.data,
        options: props.options,
      },
    });
  };

  describe('when mounted', () => {
    it('should render the single stat with default props', () => {
      createWrapper();

      expect(findSingleStat().props()).toMatchObject({
        value: 0,
        title: '',
        variant: 'muted',
        shouldAnimate: true,
        animationDecimalPlaces: 0,
        useDelimiters: true,
      });
    });

    it('should pass the visualization data to the single stat value', () => {
      createWrapper({ data: 35 });

      expect(findSingleStat().props('value')).toBe(35);
    });

    it('does not emit `showTooltip`', () => {
      createWrapper();

      expect(wrapper.emitted('showTooltip')).toBeUndefined();
    });

    describe('when there are user defined options that include decimal places', () => {
      const options = {
        title: 'Sessions',
        decimalPlaces: 2,
        metaText: 'meta text',
        metaIcon: 'project',
        titleIcon: 'users',
        unit: 'days',
      };

      it('should pass the visualization options to the single stat', () => {
        createWrapper({ options });

        expect(findSingleStat().props()).toMatchObject({
          title: 'Sessions',
          metaText: 'meta text',
          metaIcon: 'project',
          titleIcon: 'users',
          unit: 'days',
        });
      });

      it.each`
        data         | animationDecimalPlaces
        ${undefined} | ${0}
        ${35}        | ${options.decimalPlaces}
      `(
        'should display $animationDecimalPlaces decimal places when the data is "$data"',
        ({ data, animationDecimalPlaces }) => {
          createWrapper({ data, options });

          expect(findSingleStat().props()).toMatchObject({ animationDecimalPlaces });
        },
      );
    });

    describe('when options include tooltip', () => {
      const tooltip = { description: 'Example tooltip', descriptionLink: '/foo' };

      beforeEach(() => {
        createWrapper({ options: { tooltip } });
      });

      it('emits `showTooltip` with tooltip text', () => {
        expect(wrapper.emitted('showTooltip')).toHaveLength(1);
        expect(wrapper.emitted('showTooltip')[0][0]).toEqual(tooltip);
      });
    });
  });
});
