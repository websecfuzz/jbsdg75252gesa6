import { groupLabels, labelStartEvent, labelEndEvent } from '../mock_data';

export const MERGE_REQUEST_CREATED = 'merge_request_created';
export const ISSUE_CREATED = 'issue_created';
export const MERGE_REQUEST_CLOSED = 'merge_request_closed';
export const ISSUE_CLOSED = 'issue_closed';

export const emptyState = {
  id: null,
  name: null,
  startEventIdentifier: null,
  startEventLabelId: null,
  endEventIdentifier: null,
  endEventLabelId: null,
};

export const emptyErrorsState = {
  id: [],
  name: [],
  startEventIdentifier: [],
  startEventLabelId: [],
  endEventIdentifier: ['Please select a start event first'],
  endEventLabelId: [],
};

export const firstLabel = groupLabels[0];

export const formInitialData = {
  id: 74,
  name: 'Cool stage pre',
  startEventIdentifier: labelStartEvent.identifier,
  startEventLabelId: firstLabel.id,
  endEventIdentifier: labelEndEvent.identifier,
  endEventLabelId: firstLabel.id,
};

export const minimumFields = {
  name: 'Cool stage',
  startEventIdentifier: MERGE_REQUEST_CREATED,
  endEventIdentifier: MERGE_REQUEST_CLOSED,
};

export const defaultStages = [
  {
    name: 'issue',
    custom: false,
    relativePosition: 1,
    startEventIdentifier: 'issue_created',
    endEventIdentifier: 'issue_stage_end',
  },
  {
    name: 'plan',
    custom: false,
    relativePosition: 2,
    startEventIdentifier: 'plan_stage_start',
    endEventIdentifier: 'issue_first_mentioned_in_commit',
  },
  {
    name: 'code',
    custom: false,
    relativePosition: 3,
    startEventIdentifier: 'code_stage_start',
    endEventIdentifier: 'merge_request_created',
  },
];

export const mockLabels = [
  {
    id: 'gid://gitlab/GroupLabel/1',
    title: 'Red',
    color: '#FF0000',
    textColor: '#FFF',
    __typename: 'Label',
  },
  {
    id: 'gid://gitlab/GroupLabel/2',
    title: 'Green',
    color: '#00FF00',
    textColor: '#FFF',
    __typename: 'Label',
  },
  {
    id: 'gid://gitlab/GroupLabel/3',
    title: 'Blue',
    color: '#0000FF',
    textColor: '#FFF',
    __typename: 'Label',
  },
];

export const createMockLabelsResponse = (nodes) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      labels: {
        nodes,
      },
    },
  },
});

export const mockLabelsResponse = createMockLabelsResponse(mockLabels);

export const mockStages = [
  {
    id: 'gid://gitlab/ValueStream::Stage/1',
    name: 'default',
    custom: false,
    hidden: false,
    startEventHtmlDescription: 'description',
    endEventHtmlDescription: 'description',
    startEventIdentifier: 'ISSUE_CREATED',
    endEventIdentifier: 'ISSUE_CLOSED',
    startEventLabel: null,
    endEventLabel: null,
    __typename: 'ValueStreamStage',
  },
  {
    id: 'gid://gitlab/ValueStream::Stage/2',
    name: 'custom',
    custom: true,
    hidden: false,
    startEventHtmlDescription: 'description',
    endEventHtmlDescription: 'description',
    startEventIdentifier: 'ISSUE_LABEL_ADDED',
    endEventIdentifier: 'ISSUE_LABEL_REMOVED',
    startEventLabel: { id: mockLabels[0].id },
    endEventLabel: { id: mockLabels[1].id },
    __typename: 'ValueStreamStage',
  },
  {
    id: 'gid://gitlab/ValueStream::Stage/3',
    name: 'hidden',
    custom: false,
    hidden: true,
    startEventHtmlDescription: 'description',
    endEventHtmlDescription: 'description',
    startEventIdentifier: 'MERGE_REQUEST_CREATED',
    endEventIdentifier: 'MERGE_REQUEST_CLOSED',
    startEventLabel: null,
    endEventLabel: null,
    __typename: 'ValueStreamStage',
  },
];

export const mockValueStream = {
  id: 'gid://gitlab/ValueStream/1',
  name: 'oink',
  stages: mockStages,
  __typename: 'ValueStream',
};

export const createMockValueStreamResponse = (valueStream) => ({
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      valueStreams: {
        nodes: [valueStream],
        __typename: 'ValueStreamConnection',
      },
      __typename: 'Group',
    },
    project: null,
  },
});

export const mockValueStreamResponse = createMockValueStreamResponse(mockValueStream);

export const mockChangeValueStreamResponse = {
  data: {
    valueStreamChange: {
      valueStream: {
        id: 13,
      },
      errors: [],
    },
  },
};
