import { GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoSiteProgressBar from 'ee/geo_sites/components/details/geo_site_progress_bar.vue';
import StackedProgressBar from 'ee/geo_sites/components/details/stacked_progress_bar.vue';
import { MOCK_VERIFICATION_INFO } from 'ee_jest/geo_sites/mock_data';

describe('GeoSiteProgressBar', () => {
  let wrapper;

  const defaultProps = {
    title: MOCK_VERIFICATION_INFO[1].title,
    values: MOCK_VERIFICATION_INFO[1].values,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(GeoSiteProgressBar, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findStackedProgressBar = () => wrapper.findComponent(StackedProgressBar);
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findCounts = () => wrapper.findAllByTestId('geo-progress-count');
  const findDisabledText = () => wrapper.findByText('Disabled');

  describe('template', () => {
    describe('when values are provided', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the stacked progress bar', () => {
        expect(findStackedProgressBar().exists()).toBe(true);
      });

      it('renders the GlPopover', () => {
        expect(findGlPopover().exists()).toBe(true);
      });

      it('renders a popover count for total, successful, queued, and failed', () => {
        expect(findCounts()).toHaveLength(4);
      });

      it('does not render disabled text', () => {
        expect(findDisabledText().exists()).toBe(false);
      });
    });

    describe('when values are not provided', () => {
      beforeEach(() => {
        createComponent({ values: null });
      });

      it('does not render the stacked progress bar', () => {
        expect(findStackedProgressBar().exists()).toBe(false);
      });

      it('does render disabled text', () => {
        expect(findDisabledText().exists()).toBe(true);
      });
    });

    describe.each`
      values                                             | expectedUiCounts
      ${{ success: 5, failed: 3, total: 10 }}            | ${['Total 10', 'Synced 5', 'Queued 2', 'Failed 3']}
      ${{ success: '5', failed: '3', total: '10' }}      | ${['Total 10', 'Synced 5', 'Queued 2', 'Failed 3']}
      ${{ success: null, failed: null, total: null }}    | ${['Total 0', 'Synced 0', 'Queued 0', 'Failed 0']}
      ${{ success: 'abc', failed: 'def', total: 'ghi' }} | ${['Total 0', 'Synced 0', 'Queued 0', 'Failed 0']}
    `(`status counts`, ({ values, expectedUiCounts }) => {
      beforeEach(() => {
        createComponent({ values });
      });

      describe(`when values are { total: ${values.total}, success: ${values.success}, failed: ${values.failed}} `, () => {
        it(`should render the ui counts as ${expectedUiCounts}`, () => {
          expect(findCounts().wrappers.map((w) => w.text())).toStrictEqual(expectedUiCounts);
        });
      });
    });

    describe('when status counts labels are over written', () => {
      const expectedUiCounts = ['Total 0', 'label1 0', 'label2 0', 'label3 0'];
      const values = { success: 0, failed: 0, total: 0 };

      beforeEach(() => {
        createComponent({
          successLabel: 'label1',
          queuedLabel: 'label2',
          failedLabel: 'label3',
          values,
        });
      });

      it('uses the custom labels instead of the default', () => {
        expect(findCounts().wrappers.map((w) => w.text())).toStrictEqual(expectedUiCounts);
      });
    });

    describe('popoverTarget', () => {
      describe('when target prop is null', () => {
        beforeEach(() => {
          createComponent();
        });

        it(`sets the popoverTarget to syncProgress-${MOCK_VERIFICATION_INFO[1].title}`, () => {
          expect(findStackedProgressBar().attributes('id')).toBe(
            `syncProgress-${MOCK_VERIFICATION_INFO[1].title}`,
          );
          expect(findGlPopover().attributes('target')).toBe(
            `syncProgress-${MOCK_VERIFICATION_INFO[1].title}`,
          );
        });
      });

      describe('when target prop is set', () => {
        beforeEach(() => {
          createComponent({ target: 'test-target' });
        });

        it('sets the popoverTarget to test-target', () => {
          expect(findStackedProgressBar().attributes('id')).toBe('test-target');
          expect(findGlPopover().attributes('target')).toBe('test-target');
        });
      });
    });
  });
});
