import { GlButton, GlDropdown, GlDropdownItem } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';

import VueApollo from 'vue-apollo';
import IterationSelect from 'ee/boards/components/iteration_select.vue';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { boardObj } from 'jest/boards/mock_data';

import searchIterationQuery from 'ee/issues/list/queries/search_iterations.query.graphql';
import { ANY_ITERATION, CURRENT_ITERATION, IterationFilterType } from 'ee/boards/constants';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { WORKSPACE_GROUP } from '~/issues/constants';
import DropdownWidget from '~/vue_shared/components/dropdown/dropdown_widget/dropdown_widget.vue';
import { mockIterationsResponse, mockIterations, mockIterationCadence } from './mock_data';

Vue.use(VueApollo);

describe('Iteration select component', () => {
  let wrapper;
  let fakeApollo;

  const mockAnyIterationInCadence = {
    id: ANY_ITERATION.id,
    title: IterationFilterType.any,
    iterationCadenceId: mockIterationCadence.id,
    cadenceTitle: mockIterationCadence.title,
  };

  const mockCurrentIterationInCadence = {
    id: CURRENT_ITERATION.id,
    title: IterationFilterType.current,
    iterationCadenceId: mockIterationCadence.id,
    cadenceTitle: mockIterationCadence.title,
  };

  const selectedText = () => wrapper.findByTestId('selected-iteration').text();
  const findEditButton = () => wrapper.findComponent(GlButton);
  const findDropdown = () => wrapper.findComponent(DropdownWidget);

  const iterationsQueryHandlerSuccess = jest.fn().mockResolvedValue(mockIterationsResponse);
  const errorMessage = 'Failed to fetch iterations';
  const iterationsQueryHandlerFailure = jest.fn().mockRejectedValue(new Error(errorMessage));

  const createComponent = ({
    props = {},
    iterationsQueryHandler = iterationsQueryHandlerSuccess,
  } = {}) => {
    fakeApollo = createMockApollo([[searchIterationQuery, iterationsQueryHandler]]);
    wrapper = shallowMountExtended(IterationSelect, {
      apolloProvider: fakeApollo,
      propsData: {
        board: boardObj,
        canEdit: true,
        ...props,
      },
      provide: {
        fullPath: 'gitlab-org',
        boardType: WORKSPACE_GROUP,
        isGroupBoard: true,
        isProjectBoard: false,
      },
      stubs: {
        GlDropdown,
        GlDropdownItem,
        DropdownWidget: stubComponent(DropdownWidget, {
          methods: { showDropdown: jest.fn() },
        }),
      },
    });
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('when not editing', () => {
    beforeEach(() => {
      createComponent();
    });

    it('defaults to Any iteration', () => {
      expect(selectedText()).toContain('Any iteration');
    });

    it('skips the queries and does not render dropdown', () => {
      expect(iterationsQueryHandlerSuccess).not.toHaveBeenCalled();
      expect(findDropdown().isVisible()).toBe(false);
    });

    it('renders selected iteration', async () => {
      findEditButton().vm.$emit('click');

      findDropdown().vm.$emit('set-option', mockIterations[1]);
      await nextTick();

      expect(selectedText()).toContain(mockIterations[1].title);
    });

    it('shows Edit button if canEdit is true', () => {
      expect(findEditButton().exists()).toBe(true);
    });

    it('toggles edit state when edit button is clicked', async () => {
      findEditButton().vm.$emit('click');
      await nextTick();
      expect(findDropdown().isVisible()).toBe(true);

      findEditButton().vm.$emit('click');
      await nextTick();
      expect(findDropdown().isVisible()).toBe(false);
    });

    it('renders cadence when Any in cadence is selected', async () => {
      findEditButton().vm.$emit('click');

      findDropdown().vm.$emit('set-option', mockAnyIterationInCadence);
      await nextTick();

      expect(selectedText()).toBe(`Any iteration in ${mockIterationCadence.title}`);
    });

    it('renders cadence when Current in cadence is selected', async () => {
      findEditButton().vm.$emit('click');

      findDropdown().vm.$emit('set-option', mockCurrentIterationInCadence);
      await nextTick();

      expect(selectedText()).toBe(`Current iteration in ${mockIterationCadence.title}`);
    });
  });

  describe('when editing', () => {
    beforeEach(() => {
      createComponent();
    });

    it('trigger query and renders dropdown with passed iterations', async () => {
      findEditButton().vm.$emit('click');
      await waitForPromises();
      expect(iterationsQueryHandlerSuccess).toHaveBeenCalled();

      expect(findDropdown().isVisible()).toBe(true);
    });

    it('sets error when fetching iterations fails', async () => {
      createComponent({ iterationsQueryHandler: iterationsQueryHandlerFailure });
      await nextTick();
      findEditButton().vm.$emit('click');
      await waitForPromises();
      expect(cacheUpdates.setError).toHaveBeenCalled();
    });
  });

  describe('canEdit', () => {
    beforeEach(() => {
      createComponent({ props: { canEdit: false } });
    });

    it('hides Edit button if false', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });
});
