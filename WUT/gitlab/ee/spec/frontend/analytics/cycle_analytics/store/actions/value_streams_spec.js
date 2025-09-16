import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import * as actions from 'ee/analytics/cycle_analytics/store/actions/value_streams';
import * as getters from 'ee/analytics/cycle_analytics/store/getters';
import * as types from 'ee/analytics/cycle_analytics/store/mutation_types';
import testAction from 'helpers/vuex_action_helper';
import { currentGroup } from 'jest/analytics/cycle_analytics/mock_data';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { allowedStages as stages, endpoints, valueStreams } from '../../mock_data';

stages[0].hidden = true;
const activeStages = stages.filter(({ hidden }) => !hidden);

const [selectedStage] = activeStages;
const selectedStageSlug = selectedStage.slug;
const [selectedValueStream] = valueStreams;

const mockGetters = {
  currentGroupPath: () => currentGroup.fullPath,
  currentValueStreamId: () => selectedValueStream.id,
};

describe('Value Stream Analytics actions / value streams', () => {
  let state;
  let mock;

  beforeEach(() => {
    state = {
      stages: [],
      activeStages,
      selectedValueStream,
      ...mockGetters,
    };
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
    state = { ...state, currentGroup: null };
  });

  describe('setSelectedValueStream', () => {
    const vs = { id: 'vs-1', name: 'Value stream 1' };

    it('refetches the Value Stream Analytics data', () => {
      return testAction(
        actions.setSelectedValueStream,
        vs,
        { ...state, selectedValueStream: {} },
        [{ type: types.SET_SELECTED_VALUE_STREAM, payload: vs }],
        [{ type: 'setDefaultSelectedStage' }, { type: 'fetchValueStreamData' }],
      );
    });
  });

  describe('deleteValueStream', () => {
    const payload = 'my-fake-value-stream';

    beforeEach(() => {
      state = { currentGroup };
    });

    describe('with no errors', () => {
      beforeEach(() => {
        mock.onDelete(endpoints.valueStreamData).replyOnce(HTTP_STATUS_OK, {});
      });

      it(`commits the ${types.REQUEST_DELETE_VALUE_STREAM} and ${types.RECEIVE_DELETE_VALUE_STREAM_SUCCESS} actions`, () => {
        return testAction(
          actions.deleteValueStream,
          payload,
          state,
          [
            {
              type: types.REQUEST_DELETE_VALUE_STREAM,
            },
            {
              type: types.RECEIVE_DELETE_VALUE_STREAM_SUCCESS,
            },
          ],
          [{ type: 'fetchCycleAnalyticsData' }],
        );
      });
    });

    describe('with errors', () => {
      const message = { message: 'failed to delete the value stream' };
      const resp = { message };
      beforeEach(() => {
        mock.onDelete(endpoints.valueStreamData).replyOnce(HTTP_STATUS_NOT_FOUND, resp);
      });

      it(`commits the ${types.REQUEST_DELETE_VALUE_STREAM} and ${types.RECEIVE_DELETE_VALUE_STREAM_ERROR} actions `, () => {
        return testAction(
          actions.deleteValueStream,
          payload,
          state,
          [
            { type: types.REQUEST_DELETE_VALUE_STREAM },
            {
              type: types.RECEIVE_DELETE_VALUE_STREAM_ERROR,
              payload: message,
            },
          ],
          [],
        );
      });
    });
  });

  describe('fetchValueStreams', () => {
    beforeEach(() => {
      state = {
        ...state,
        stages: [{ slug: selectedStageSlug }],
        currentGroup,
        features: {
          ...state.features,
        },
        ...mockGetters,
      };
      mock = new MockAdapter(axios);
      mock.onGet(endpoints.valueStreamData).reply(HTTP_STATUS_OK, { stages: [], events: [] });
    });

    it(`commits ${types.REQUEST_VALUE_STREAMS} and dispatches receiveValueStreamsSuccess with received data on success`, () => {
      return testAction(
        actions.fetchValueStreams,
        null,
        state,
        [{ type: types.REQUEST_VALUE_STREAMS }],
        [
          {
            payload: {
              events: [],
              stages: [],
            },
            type: 'receiveValueStreamsSuccess',
          },
        ],
      );
    });

    describe('with a failing request', () => {
      let mockCommit;
      beforeEach(() => {
        mockCommit = jest.fn();
        mock.onGet(endpoints.valueStreamData).reply(HTTP_STATUS_NOT_FOUND);
      });

      it(`will commit ${types.RECEIVE_VALUE_STREAMS_ERROR}`, () => {
        return actions.fetchValueStreams({ state, getters, commit: mockCommit }).catch(() => {
          expect(mockCommit.mock.calls).toEqual([
            ['REQUEST_VALUE_STREAMS'],
            ['RECEIVE_VALUE_STREAMS_ERROR', HTTP_STATUS_NOT_FOUND],
          ]);
        });
      });

      it(`throws an error`, () => {
        return expect(
          actions.fetchValueStreams({ state, getters, commit: mockCommit }),
        ).rejects.toThrow('Request failed with status code 404');
      });
    });

    describe('receiveValueStreamsSuccess', () => {
      it(`with a selectedValueStream in state commits the ${types.RECEIVE_VALUE_STREAMS_SUCCESS} mutation and dispatches 'fetchValueStreamData' and 'fetchStageCountValues'`, () => {
        return testAction(
          actions.receiveValueStreamsSuccess,
          valueStreams,
          state,
          [
            {
              type: types.RECEIVE_VALUE_STREAMS_SUCCESS,
              payload: valueStreams,
            },
          ],
          [{ type: 'fetchValueStreamData' }],
        );
      });

      it(`commits the ${types.RECEIVE_VALUE_STREAMS_SUCCESS} mutation and dispatches 'setSelectedValueStream' and 'fetchStageCountValues'`, () => {
        return testAction(
          actions.receiveValueStreamsSuccess,
          valueStreams,
          {
            ...state,
            selectedValueStream: null,
          },
          [
            {
              type: types.RECEIVE_VALUE_STREAMS_SUCCESS,
              payload: valueStreams,
            },
          ],
          [
            { type: 'setSelectedValueStream', payload: selectedValueStream },
            { type: 'fetchStageCountValues' },
          ],
        );
      });
    });

    describe('with no selectedValueStream and no data returned', () => {
      it(`commits the ${types.RECEIVE_VALUE_STREAMS_SUCCESS} mutation`, () => {
        return testAction(
          actions.receiveValueStreamsSuccess,
          [],
          {
            ...state,
            selectedValueStream: null,
          },
          [
            {
              type: types.RECEIVE_VALUE_STREAMS_SUCCESS,
              payload: [],
            },
          ],
          [{ type: 'fetchGroupStages' }],
        );
      });
    });
  });

  describe('fetchValueStreamData', () => {
    beforeEach(() => {
      state = {
        ...state,
        stages: [{ slug: selectedStageSlug }],
        currentGroup,
        features: {
          ...state.features,
        },
      };
      mock = new MockAdapter(axios);
      mock.onGet(endpoints.valueStreamData).reply(HTTP_STATUS_OK, { stages: [], events: [] });
    });

    it('dispatches fetchGroupStages, fetchStageCountValues and fetchStageMedianValues', () => {
      return testAction(
        actions.fetchValueStreamData,
        null,
        state,
        [],
        [
          { type: 'fetchGroupStages' },
          { type: 'fetchStageCountValues' },
          { type: 'fetchStageMedianValues' },
        ],
      );
    });
  });
});
