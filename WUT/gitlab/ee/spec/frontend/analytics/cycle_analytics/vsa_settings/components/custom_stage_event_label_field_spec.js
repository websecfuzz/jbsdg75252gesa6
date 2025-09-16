import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CustomStageEventLabelField from 'ee/analytics/cycle_analytics/vsa_settings/components/custom_stage_event_label_field.vue';
import getCustomStageLabels from 'ee/analytics/cycle_analytics/vsa_settings/graphql/get_custom_stage_labels.query.graphql';
import { mockLabels, mockLabelsResponse, createMockLabelsResponse } from '../mock_data';

Vue.use(VueApollo);

const index = 0;
const eventType = 'start-event';

const defaultProps = {
  index,
  eventType,
  fieldLabel: 'label',
  requiresLabel: true,
};

describe('CustomStageEventLabelField', () => {
  let wrapper;

  const [selectedLabel] = mockLabels;

  const createWrapper = ({
    props = {},
    labelsResolver = jest.fn().mockResolvedValue(mockLabelsResponse),
  } = {}) => {
    const apolloProvider = createMockApollo([[getCustomStageLabels, labelsResolver]]);

    wrapper = shallowMountExtended(CustomStageEventLabelField, {
      apolloProvider,
      provide: { groupPath: 'test' },
      propsData: {
        ...defaultProps,
        ...props,
      },
    });

    jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    return waitForPromises();
  };

  const findEventLabelField = () =>
    wrapper.findByTestId(`custom-stage-${eventType}-label-${index}`);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findToggleButton = () => wrapper.findByTestId('listbox-toggle-btn');

  describe('Label listbox', () => {
    beforeEach(() => {
      return createWrapper();
    });

    it('renders the form group', () => {
      expect(findEventLabelField().attributes()).toMatchObject({
        label: defaultProps.fieldLabel,
        state: 'true',
        'invalid-feedback': '',
      });

      expect(findToggleButton().classes()).not.toContain('gl-shadow-inner-1-red-500');
    });

    it('does not show the searching state', () => {
      expect(findCollapsibleListbox().props().searching).toBe(false);
    });

    it('shows the labels in the listbox', () => {
      expect(findCollapsibleListbox().props().items).toHaveLength(mockLabels.length);
    });

    it('renders with no selected label', () => {
      expect(findCollapsibleListbox().props().selected).toBeNull();
    });

    it('emits the `update-label` event when a label is selected', () => {
      expect(wrapper.emitted('update-label')).toBeUndefined();

      findCollapsibleListbox().vm.$emit('select', selectedLabel.id);

      expect(wrapper.emitted('update-label')).toHaveLength(1);
      expect(wrapper.emitted('update-label')[0]).toEqual([{ id: selectedLabel.id }]);
    });
  });

  describe('with selected label', () => {
    beforeEach(() => {
      return createWrapper({ props: { selectedLabelId: selectedLabel.id } });
    });

    it('sets the selected label', () => {
      expect(findCollapsibleListbox().props().selected).toBe(selectedLabel.id);
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the listbox searching state', () => {
      expect(findCollapsibleListbox().props().searching).toBe(true);
    });
  });

  describe('when the labels request fails', () => {
    beforeEach(() => {
      return createWrapper({ labelsResolver: jest.fn().mockRejectedValue({}) });
    });

    it('stops the loading state', () => {
      expect(findCollapsibleListbox().props().searching).toBe(false);
    });

    it('emits an error', () => {
      expect(wrapper.emitted('error')).toHaveLength(1);
      expect(wrapper.emitted('error')[0]).toEqual([
        'There was an error fetching label data for the selected group',
      ]);
    });
  });

  describe('when searching', () => {
    const results = mockLabels.slice(0, 1);

    beforeEach(async () => {
      await createWrapper({
        labelsResolver: jest.fn().mockResolvedValue(createMockLabelsResponse(results)),
      });

      findCollapsibleListbox().vm.$emit('search', 'query');
      await nextTick();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
    });

    it('will show searching state while request is pending', () => {
      expect(findCollapsibleListbox().props().searching).toBe(true);
    });

    describe('once request finishes', () => {
      beforeEach(() => {
        return waitForPromises();
      });

      it('stops the loading state', () => {
        expect(findCollapsibleListbox().props().searching).toBe(false);
      });

      it('shows the labels in the listbox', () => {
        expect(findCollapsibleListbox().props().items).toHaveLength(results.length);
      });
    });
  });

  describe('with `requiresLabel=false`', () => {
    beforeEach(() => {
      createWrapper({ props: { requiresLabel: false } });
    });

    it('sets the form group error state', () => {
      expect(findEventLabelField().exists()).toBe(false);
    });
  });

  describe('with an event field error', () => {
    const labelError = 'error';

    beforeEach(() => {
      createWrapper({
        props: {
          isLabelValid: false,
          labelError,
        },
      });
    });

    it('sets the form group error state', () => {
      expect(findEventLabelField().attributes('state')).toBeUndefined();
      expect(findEventLabelField().attributes('invalid-feedback')).toBe(labelError);
    });

    it('sets the listbox toggle button error state', () => {
      expect(findToggleButton().classes()).toContain('gl-shadow-inner-1-red-500');
    });
  });
});
