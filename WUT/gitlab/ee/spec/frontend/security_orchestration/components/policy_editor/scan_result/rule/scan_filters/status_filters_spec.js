import StatusFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filters.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filter.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('StatusFilters', () => {
  let wrapper;

  const testStateNew = 'new_needs_triage';
  const testStatePreviouslyDetected = 'detected';
  const selectedBothFilters = {
    [NEWLY_DETECTED]: [testStateNew],
    [PREVIOUSLY_EXISTING]: [testStatePreviouslyDetected],
  };
  const filtersNewlyDetected = { [NEWLY_DETECTED]: true };
  const filtersPreviouslyExisting = { [PREVIOUSLY_EXISTING]: true };
  const filtersBoth = { ...filtersNewlyDetected, ...filtersPreviouslyExisting };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(StatusFilters, {
      propsData: {
        ...props,
      },
    });
  };

  const findStatusFilters = () => wrapper.findAllComponents(StatusFilter);

  it('renders nothing initially', () => {
    createComponent();

    expect(findStatusFilters()).toHaveLength(0);
  });

  describe('select', () => {
    it.each`
      filters                      | filtersCount
      ${filtersNewlyDetected}      | ${1}
      ${filtersPreviouslyExisting} | ${1}
      ${filtersBoth}               | ${2}
    `(
      'renders $filtersCount filter(s) based for selected $filters',
      ({ filters, filtersCount }) => {
        createComponent({ filters });

        expect(findStatusFilters()).toHaveLength(filtersCount);
      },
    );

    it('should emit input events on statuses changes', () => {
      createComponent({ filters: filtersBoth, selected: selectedBothFilters });

      findStatusFilters().at(0).vm.$emit('input', []);
      findStatusFilters().at(1).vm.$emit('input', []);

      expect(wrapper.emitted('input')).toEqual([
        [
          {
            [NEWLY_DETECTED]: [],
            [PREVIOUSLY_EXISTING]: [testStatePreviouslyDetected],
          },
        ],
        [
          {
            [NEWLY_DETECTED]: [testStateNew],
            [PREVIOUSLY_EXISTING]: [],
          },
        ],
      ]);
    });

    describe('change status group', () => {
      it('should select PREVIOUSLY_EXISTING vulnerability state and emit change-status-group event', async () => {
        createComponent({ filters: filtersNewlyDetected });

        await findStatusFilters().at(0).vm.$emit('change-group', PREVIOUSLY_EXISTING);

        expect(wrapper.emitted('change-status-group')).toEqual([
          [{ [NEWLY_DETECTED]: null, [PREVIOUSLY_EXISTING]: [] }],
        ]);
      });

      it('should select NEWLY_DETECTED with default vulnerability states and emit change-status-group event', async () => {
        createComponent({
          filters: filtersPreviouslyExisting,
        });

        await findStatusFilters().at(0).vm.$emit('change-group', NEWLY_DETECTED);

        expect(wrapper.emitted('change-status-group')).toEqual([
          [
            {
              [PREVIOUSLY_EXISTING]: null,
              [NEWLY_DETECTED]: ['new_needs_triage', 'new_dismissed'],
            },
          ],
        ]);
      });
    });

    it.each`
      filters                      | disabled
      ${filtersNewlyDetected}      | ${false}
      ${filtersPreviouslyExisting} | ${false}
      ${filtersBoth}               | ${true}
    `('renders filter with disabled=$disabled for $filters', ({ filters, disabled }) => {
      createComponent({ filters });

      for (let i = 0; i < findStatusFilters().length; i += 1) {
        expect(findStatusFilters().at(i).props('disabled')).toEqual(disabled);
      }
    });
  });

  describe('remove', () => {
    it('should remove filter', async () => {
      createComponent({ filters: filtersBoth });

      await findStatusFilters().at(1).vm.$emit('remove', PREVIOUSLY_EXISTING);

      expect(wrapper.emitted('remove')).toContainEqual([PREVIOUSLY_EXISTING]);
    });
  });

  describe('custom label and css class', () => {
    it('add custom padding when all filters selected', () => {
      createComponent({
        filters: filtersBoth,
      });

      expect(findStatusFilters().at(0).classes()).toContain('gl-pb-3');
      expect(findStatusFilters().at(1).classes()).toContain('gl-pt-2');

      expect(findStatusFilters().at(0).props('labelClasses')).toContain(
        '!gl-text-base !gl-w-10 md:!gl-w-12 !gl-pl-0 !gl-font-bold',
      );
      expect(findStatusFilters().at(1).props('labelClasses')).toContain('!gl-w-12 !gl-pl-0');

      expect(findStatusFilters().at(1).props('label')).toBe('or');
    });
  });
});
