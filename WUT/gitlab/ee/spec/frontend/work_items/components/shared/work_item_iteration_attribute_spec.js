import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkItemIterationAttribute from 'ee/work_items/components/shared/work_item_iteration_attribute.vue';
import { workItemObjectiveMetadataWidgetsEE } from '../../mock_data';

describe('WorkItemIterations', () => {
  let wrapper;

  const { ITERATION } = workItemObjectiveMetadataWidgetsEE;

  const findIteration = () => wrapper.findByTestId('iteration-attribute');

  const createComponent = ({ iteration } = {}) => {
    wrapper = shallowMountExtended(WorkItemIterationAttribute, {
      propsData: {
        iteration,
      },
    });
  };

  describe('iteration', () => {
    beforeEach(() => {
      createComponent({
        iteration: ITERATION.iteration,
      });
    });

    it('renders item iteration icon and name', () => {
      expect(findIteration().exists()).toBe(true);
      expect(findIteration().findComponent(GlIcon).props('name')).toBe('iteration');
      expect(findIteration().text()).toContain('Dec 19, 2023 – Jan 15, 2024');
    });

    it('renders iteration title in bold', () => {
      expect(wrapper.findByTestId('iteration-title').text()).toBe('Iteration');
    });

    it('renders iteration tooltip text', () => {
      expect(wrapper.findByTestId('iteration-cadence-text').text()).toBe(
        ITERATION.iteration.iterationCadence.title,
      );
      expect(wrapper.findByTestId('iteration-title-text').text()).toBe(ITERATION.iteration.title);
      expect(wrapper.findByTestId('iteration-period-text').text()).toBe(
        'Dec 19, 2023 – Jan 15, 2024',
      );
    });
  });
});
