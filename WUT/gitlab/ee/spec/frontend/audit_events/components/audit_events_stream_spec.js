import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlDisclosureDropdown, GlDisclosureDropdownItem, GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupStreamingDestinationsQuery from 'ee/audit_events/graphql/queries/get_group_streaming_destinations.query.graphql';
import instanceStreamingDestinationsQuery from 'ee/audit_events/graphql/queries/get_instance_streaming_destinations.query.graphql';
import externalDestinationsQuery from 'ee/audit_events/graphql/queries/get_external_destinations.query.graphql';
import instanceExternalDestinationsQuery from 'ee/audit_events/graphql/queries/get_instance_external_destinations.query.graphql';
import gcpLoggingDestinationsQuery from 'ee/audit_events/graphql/queries/get_google_cloud_logging_destinations.query.graphql';
import instanceGcpLoggingDestinationsQuery from 'ee/audit_events/graphql/queries/get_instance_google_cloud_logging_destinations.query.graphql';
import amazonS3DestinationsQuery from 'ee/audit_events/graphql/queries/get_amazon_s3_destinations.query.graphql';
import instanceAmazonS3DestinationsQuery from 'ee/audit_events/graphql/queries/get_instance_amazon_s3_destinations.query.graphql';

import {
  AUDIT_STREAMS_NETWORK_ERRORS,
  ADD_STREAM_MESSAGE,
  DELETE_STREAM_MESSAGE,
} from 'ee/audit_events/constants';
import AuditEventsStream from 'ee/audit_events/components/audit_events_stream.vue';
import StreamDestinationEditor from 'ee/audit_events/components/stream/stream_destination_editor.vue';
import StreamHttpDestinationEditor from 'ee/audit_events/components/stream/stream_http_destination_editor.vue';
import StreamGcpLoggingDestinationEditor from 'ee/audit_events/components/stream/stream_gcp_logging_destination_editor.vue';
import StreamAmazonS3DestinationEditor from 'ee/audit_events/components/stream/stream_amazon_s3_destination_editor.vue';
import StreamItem from 'ee/audit_events/components/stream/stream_item.vue';
import StreamEmptyState from 'ee/audit_events/components/stream/stream_empty_state.vue';
import {
  mockExternalDestinations,
  groupPath,
  destinationDataPopulator,
  mockInstanceExternalDestinations,
  instanceGroupPath,
  instanceDestinationDataPopulator,
  gcpLoggingDataPopulator,
  mockGcpLoggingDestinations,
  mockInstanceGcpLoggingDestinations,
  mockAmazonS3Destinations,
  mockInstanceAmazonS3Destinations,
} from '../mock_data';
import {
  mockAllAPIDestinations,
  groupStreamingDestinationDataPopulator,
  instanceStreamingDestinationDataPopulator,
} from '../mock_data/consolidated_api';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');
Vue.use(VueApollo);

describe('AuditEventsStream', () => {
  let wrapper;
  let providedGroupPath = groupPath;

  const streamingDestinationsQuerySpy = jest
    .fn()
    .mockResolvedValue(groupStreamingDestinationDataPopulator(mockAllAPIDestinations));
  const instanceStreamingDestinationsQuerySpy = jest
    .fn()
    .mockResolvedValue(instanceStreamingDestinationDataPopulator(mockAllAPIDestinations));
  const externalDestinationsQuerySpy = jest
    .fn()
    .mockResolvedValue(destinationDataPopulator(mockExternalDestinations));
  const externalGcpLoggingQuerySpy = jest
    .fn()
    .mockResolvedValue(gcpLoggingDataPopulator(mockGcpLoggingDestinations));
  const externalAmazonS3QuerySpy = jest
    .fn()
    .mockResolvedValue(gcpLoggingDataPopulator(mockAmazonS3Destinations));

  const defaultProvide = {
    glFeatures: { useConsolidatedAuditEventStreamDestApi: false },
  };

  const createComponent = ({ apolloProvider, provide = defaultProvide } = {}) => {
    wrapper = mountExtended(AuditEventsStream, {
      provide: {
        groupPath: providedGroupPath,
        ...provide,
      },
      apolloProvider,
      stubs: {
        GlAlert: true,
        GlLoadingIcon: true,
        StreamItem: true,
        StreamDestinationEditor: true,
        StreamHttpDestinationEditor: true,
        StreamGcpLoggingDestinationEditor: true,
        StreamAmazonS3DestinationEditor: true,
        StreamEmptyState: true,
      },
    });
  };

  const findSuccessMessage = () => wrapper.findComponent(GlAlert);
  const findAddDestinationButton = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDisclosureDropdownItem = (index) =>
    wrapper.findAllComponents(GlDisclosureDropdownItem).at(index).find('button');
  const findHttpDropdownItem = () => findDisclosureDropdownItem(0);
  const findGcpLoggingDropdownItem = () => findDisclosureDropdownItem(1);
  const findAmazonS3DropdownItem = () => findDisclosureDropdownItem(2);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStreamDestinationEditor = () => wrapper.findComponent(StreamDestinationEditor);
  const findStreamHttpDestinationEditor = () => wrapper.findComponent(StreamHttpDestinationEditor);
  const findStreamGcpLoggingDestinationEditor = () =>
    wrapper.findComponent(StreamGcpLoggingDestinationEditor);
  const findStreamAmazonS3DestinationEditor = () =>
    wrapper.findComponent(StreamAmazonS3DestinationEditor);
  const findStreamEmptyState = () => wrapper.findComponent(StreamEmptyState);
  const findStreamItems = () => wrapper.findAllComponents(StreamItem);

  afterEach(() => {
    createAlert.mockClear();
    externalDestinationsQuerySpy.mockClear();
    externalGcpLoggingQuerySpy.mockClear();
    externalAmazonS3QuerySpy.mockClear();
  });

  describe('Group AuditEventsStream', () => {
    describe('when initialized', () => {
      it('should render the loading icon while waiting for data to be returned', () => {
        const destinationQuerySpy = jest.fn();
        const apolloProvider = createMockApollo([
          [externalDestinationsQuery, destinationQuerySpy],
          [gcpLoggingDestinationsQuery, destinationQuerySpy],
          [amazonS3DestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should still render the loading icon while waiting for external destination data to be returned', async () => {
        const destinationQuerySpy = jest.fn().mockImplementation(() => {
          return new Promise(() => {});
        });
        const apolloProvider = createMockApollo([
          [externalDestinationsQuery, destinationQuerySpy],
          [gcpLoggingDestinationsQuery, externalGcpLoggingQuerySpy],
          [amazonS3DestinationsQuery, externalAmazonS3QuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should still render the loading icon while waiting for gcp logging destination data to be returned', async () => {
        const destinationQuerySpy = jest.fn().mockImplementation(() => {
          return new Promise(() => {});
        });
        const apolloProvider = createMockApollo([
          [externalDestinationsQuery, externalDestinationsQuerySpy],
          [gcpLoggingDestinationsQuery, destinationQuerySpy],
          [amazonS3DestinationsQuery, externalAmazonS3QuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should still render the loading icon while waiting for aws s3 destination data to be returned', async () => {
        const destinationQuerySpy = jest.fn().mockImplementation(() => {
          return new Promise(() => {});
        });
        const apolloProvider = createMockApollo([
          [externalDestinationsQuery, destinationQuerySpy],
          [gcpLoggingDestinationsQuery, destinationQuerySpy],
          [amazonS3DestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should render empty state when no data is returned', async () => {
        const destinationQuerySpy = jest.fn().mockResolvedValue(destinationDataPopulator([]));
        const gcpLoggingQuerySpy = jest.fn().mockResolvedValue(gcpLoggingDataPopulator([]));
        const amazonS3QuerySpy = jest.fn().mockResolvedValue(gcpLoggingDataPopulator([]));
        const apolloProvider = createMockApollo([
          [externalDestinationsQuery, destinationQuerySpy],
          [gcpLoggingDestinationsQuery, gcpLoggingQuerySpy],
          [amazonS3DestinationsQuery, amazonS3QuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamEmptyState().exists()).toBe(true);
      });

      it('should report error when server error occurred', async () => {
        const destinationQuerySpy = jest.fn().mockRejectedValue({});
        const apolloProvider = createMockApollo([[externalDestinationsQuery, destinationQuerySpy]]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: AUDIT_STREAMS_NETWORK_ERRORS.FETCHING_ERROR,
        });
      });
    });

    describe('when edit mode entered', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [externalDestinationsQuery, externalDestinationsQuerySpy],
          [gcpLoggingDestinationsQuery, externalGcpLoggingQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('shows http destination editor', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamHttpDestinationEditor().exists()).toBe(false);

        expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');

        await findHttpDropdownItem().trigger('click');

        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
      });

      it('exits edit mode when an external http destination is added', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamHttpDestinationEditor().exists()).toBe(false);

        await findHttpDropdownItem().trigger('click');

        const streamHttpDestinationEditorComponent = findStreamHttpDestinationEditor();

        expect(streamHttpDestinationEditorComponent.exists()).toBe(true);

        streamHttpDestinationEditorComponent.vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('shows gcp logging editor', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(false);

        expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');

        await findGcpLoggingDropdownItem().trigger('click');

        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(true);
      });

      it('exits edit mode when an external gcp logging destination is added', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(false);

        await findGcpLoggingDropdownItem().trigger('click');

        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(true);

        findStreamGcpLoggingDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('shows amazon s3 editor', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamAmazonS3DestinationEditor().exists()).toBe(false);

        expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');

        await findAmazonS3DropdownItem().trigger('click');

        expect(findStreamAmazonS3DestinationEditor().exists()).toBe(true);
      });

      it('exits edit mode when an external amazon s3 destination is added', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamAmazonS3DestinationEditor().exists()).toBe(false);

        await findAmazonS3DropdownItem().trigger('click');

        expect(findStreamAmazonS3DestinationEditor().exists()).toBe(true);

        findStreamAmazonS3DestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('clears the success message if an error occurs afterwards', async () => {
        await findHttpDropdownItem().trigger('click');

        findStreamHttpDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);

        await findHttpDropdownItem().trigger('click');

        await findStreamHttpDestinationEditor().vm.$emit('error');

        expect(findSuccessMessage().exists()).toBe(false);
      });
    });

    describe('Streaming items', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [externalDestinationsQuery, externalDestinationsQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('shows the items', () => {
        expect(findStreamItems()).toHaveLength(2);

        expect(findStreamItems().at(0).props('item')).toStrictEqual(mockExternalDestinations[0]);
        expect(findStreamItems().at(1).props('item')).toStrictEqual(mockExternalDestinations[1]);
      });

      it('updates list when destination is removed', async () => {
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(externalDestinationsQuerySpy).toHaveBeenCalledTimes(1);

        const currentLength = findStreamItems().length;
        findStreamItems().at(0).vm.$emit('deleted');
        await waitForPromises();
        expect(findStreamItems()).toHaveLength(currentLength - 1);
        expect(findSuccessMessage().text()).toBe(DELETE_STREAM_MESSAGE);
      });

      describe('when useConsolidatedAuditEventStreamDestApi is enabled', () => {
        beforeEach(() => {
          const apolloProvider = createMockApollo([
            [groupStreamingDestinationsQuery, streamingDestinationsQuerySpy],
          ]);
          createComponent({
            apolloProvider,
            provide: {
              glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
            },
          });

          return waitForPromises();
        });

        it('shows the items', () => {
          expect(findStreamItems()).toHaveLength(mockAllAPIDestinations.length);

          findStreamItems().wrappers.forEach((streamItem, index) => {
            expect(streamItem.props('item').id).toBe(mockAllAPIDestinations[index].id);
          });
        });

        it('captures an error when the destination category is not recognized', async () => {
          const unknownAPIDestination = {
            __typename: 'GroupAuditEventStreamingDestination',
            id: 'mock-streaming-destination-1',
            name: 'Unknown Destination 1',
            category: 'something_else',
            secretToken: '',
            config: {},
            eventTypeFilters: [],
            namespaceFilters: [],
            active: true,
          };
          const streamingDestinationsQueryUnknownCategory = jest
            .fn()
            .mockResolvedValue(groupStreamingDestinationDataPopulator([unknownAPIDestination]));
          const apolloProvider = createMockApollo([
            [groupStreamingDestinationsQuery, streamingDestinationsQueryUnknownCategory],
          ]);
          createComponent({
            apolloProvider,
            provide: {
              glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
            },
          });
          await waitForPromises();

          expect(Sentry.captureException).toHaveBeenCalledWith(
            new Error('Unknown destination category: something_else'),
          );
        });

        it('updates list when destination is removed', async () => {
          await waitForPromises();

          expect(findLoadingIcon().exists()).toBe(false);
          expect(streamingDestinationsQuerySpy).toHaveBeenCalledTimes(1);

          const currentLength = findStreamItems().length;
          findStreamItems().at(0).vm.$emit('deleted');
          await waitForPromises();
          expect(findStreamItems()).toHaveLength(currentLength - 1);
          expect(findSuccessMessage().text()).toBe(DELETE_STREAM_MESSAGE);
        });

        it('shows destination editor when entering edit mode', async () => {
          expect(findLoadingIcon().exists()).toBe(false);
          expect(findStreamDestinationEditor().exists()).toBe(false);

          expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');

          await findHttpDropdownItem().trigger('click');

          expect(findStreamDestinationEditor().exists()).toBe(true);
        });
      });
    });
  });

  describe('Instance AuditEventsStream', () => {
    beforeEach(() => {
      providedGroupPath = instanceGroupPath;
    });

    const externalInstanceDestinationsQuerySpy = jest
      .fn()
      .mockResolvedValue(instanceDestinationDataPopulator(mockInstanceExternalDestinations));
    const externalInstanceGcpLoggingQuerySpy = jest
      .fn()
      .mockResolvedValue(gcpLoggingDataPopulator(mockInstanceGcpLoggingDestinations));
    const externalInstanceAmazonS3QuerySpy = jest
      .fn()
      .mockResolvedValue(gcpLoggingDataPopulator(mockInstanceAmazonS3Destinations));

    afterEach(() => {
      createAlert.mockClear();
      externalInstanceDestinationsQuerySpy.mockClear();
      externalInstanceGcpLoggingQuerySpy.mockClear();
      externalInstanceAmazonS3QuerySpy.mockClear();
    });

    describe('when initialized', () => {
      it('should render the loading icon while waiting for data to be returned', () => {
        const destinationQuerySpy = jest.fn();
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, destinationQuerySpy],
          [instanceGcpLoggingDestinationsQuery, destinationQuerySpy],
          [instanceAmazonS3DestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should still render the loading icon while waiting for external destination data to be returned', async () => {
        const destinationQuerySpy = jest.fn().mockImplementation(() => {
          return new Promise(() => {});
        });
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, destinationQuerySpy],
          [instanceGcpLoggingDestinationsQuery, externalInstanceGcpLoggingQuerySpy],
          [instanceAmazonS3DestinationsQuery, externalInstanceAmazonS3QuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should still render the loading icon while waiting for gcp logging destination data to be returned', async () => {
        const destinationQuerySpy = jest.fn().mockImplementation(() => {
          return new Promise(() => {});
        });
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, externalInstanceDestinationsQuerySpy],
          [instanceGcpLoggingDestinationsQuery, destinationQuerySpy],
          [instanceAmazonS3DestinationsQuery, externalInstanceAmazonS3QuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should still render the loading icon while waiting for aws s3 destination data to be returned', async () => {
        const destinationQuerySpy = jest.fn().mockImplementation(() => {
          return new Promise(() => {});
        });
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, destinationQuerySpy],
          [instanceGcpLoggingDestinationsQuery, externalInstanceGcpLoggingQuerySpy],
          [instanceAmazonS3DestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should render empty state when no data is returned', async () => {
        const destinationQuerySpy = jest.fn().mockResolvedValue(destinationDataPopulator([]));
        const gcpLoggingQuerySpy = jest.fn().mockResolvedValue(gcpLoggingDataPopulator([]));
        const amazonS3QuerySpy = jest.fn().mockResolvedValue(gcpLoggingDataPopulator([]));
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, destinationQuerySpy],
          [instanceGcpLoggingDestinationsQuery, gcpLoggingQuerySpy],
          [instanceAmazonS3DestinationsQuery, amazonS3QuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamEmptyState().exists()).toBe(true);
      });

      it('should report error when server error occurred', async () => {
        const instanceDestinationQuerySpy = jest.fn().mockRejectedValue({});
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, instanceDestinationQuerySpy],
          [instanceGcpLoggingDestinationsQuery, instanceDestinationQuerySpy],
          [instanceAmazonS3DestinationsQuery, instanceDestinationQuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: AUDIT_STREAMS_NETWORK_ERRORS.FETCHING_ERROR,
        });
      });
    });

    describe('when edit mode entered', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, externalInstanceDestinationsQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('does not show loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('shows http destination editor', async () => {
        expect(findStreamHttpDestinationEditor().exists()).toBe(false);

        await findHttpDropdownItem().trigger('click');

        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
      });

      it('exits edit mode when an http external destination is added', async () => {
        expect(findStreamHttpDestinationEditor().exists()).toBe(false);

        await findHttpDropdownItem().trigger('click');

        expect(findStreamHttpDestinationEditor().exists()).toBe(true);

        findStreamHttpDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('shows gcp logging editor', async () => {
        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(false);

        expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');

        await findGcpLoggingDropdownItem().trigger('click');

        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(true);
      });

      it('exits edit mode when an external gcp logging destination is added', async () => {
        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(false);

        await findGcpLoggingDropdownItem().trigger('click');

        expect(findStreamGcpLoggingDestinationEditor().exists()).toBe(true);

        findStreamGcpLoggingDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('shows amazon s3 editor', () => {
        expect(findStreamAmazonS3DestinationEditor().exists()).toBe(false);

        expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');
      });

      it('exits edit mode when an external amazon s3 destination is added', async () => {
        expect(findStreamAmazonS3DestinationEditor().exists()).toBe(false);

        await findAmazonS3DropdownItem().trigger('click');

        expect(findStreamAmazonS3DestinationEditor().exists()).toBe(true);

        findStreamAmazonS3DestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('clears the success message if an error occurs afterwards', async () => {
        await findHttpDropdownItem().trigger('click');

        findStreamHttpDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);

        await findHttpDropdownItem().trigger('click');

        await findStreamHttpDestinationEditor().vm.$emit('error');

        expect(findSuccessMessage().exists()).toBe(false);
      });
    });

    describe('Streaming items', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [instanceExternalDestinationsQuery, externalInstanceDestinationsQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('shows the items', () => {
        expect(findStreamItems()).toHaveLength(2);

        expect(findStreamItems().at(0).props('item')).toStrictEqual(
          mockInstanceExternalDestinations[0],
        );
        expect(findStreamItems().at(1).props('item')).toStrictEqual(
          mockInstanceExternalDestinations[1],
        );
      });

      it('updates list when destination is removed', async () => {
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(externalInstanceDestinationsQuerySpy).toHaveBeenCalledTimes(1);

        const currentLength = findStreamItems().length;
        findStreamItems().at(0).vm.$emit('deleted');
        await waitForPromises();
        expect(findStreamItems()).toHaveLength(currentLength - 1);
        expect(findSuccessMessage().text()).toBe(DELETE_STREAM_MESSAGE);
      });

      describe('when useConsolidatedAuditEventStreamDestApi is enabled', () => {
        beforeEach(() => {
          const apolloProvider = createMockApollo([
            [instanceStreamingDestinationsQuery, instanceStreamingDestinationsQuerySpy],
          ]);
          createComponent({
            apolloProvider,
            provide: {
              glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
            },
          });

          return waitForPromises();
        });

        it('shows the items', () => {
          expect(findStreamItems()).toHaveLength(mockAllAPIDestinations.length);

          findStreamItems().wrappers.forEach((streamItem, index) => {
            expect(streamItem.props('item').id).toBe(mockAllAPIDestinations[index].id);
          });
        });

        it('updates list when destination is removed', async () => {
          await waitForPromises();

          expect(findLoadingIcon().exists()).toBe(false);
          expect(instanceStreamingDestinationsQuerySpy).toHaveBeenCalledTimes(1);

          const currentLength = findStreamItems().length;
          findStreamItems().at(0).vm.$emit('deleted');
          await waitForPromises();
          expect(findStreamItems()).toHaveLength(currentLength - 1);
          expect(findSuccessMessage().text()).toBe(DELETE_STREAM_MESSAGE);
        });
      });
    });
  });
});
