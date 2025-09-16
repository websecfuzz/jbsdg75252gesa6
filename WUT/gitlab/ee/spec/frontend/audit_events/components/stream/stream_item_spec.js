import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlToggle } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { STREAM_ITEMS_I18N, UPDATE_STREAM_MESSAGE } from 'ee/audit_events/constants';
import StreamItem from 'ee/audit_events/components/stream/stream_item.vue';
import StreamDestinationEditor from 'ee/audit_events/components/stream/stream_destination_editor.vue';
import StreamHttpDestinationEditor from 'ee/audit_events/components/stream/stream_http_destination_editor.vue';
import StreamGcpLoggingDestinationEditor from 'ee/audit_events/components/stream/stream_gcp_logging_destination_editor.vue';
import StreamAmazonS3DestinationEditor from 'ee/audit_events/components/stream/stream_amazon_s3_destination_editor.vue';

import groupAuditEventStreamingDestinationsUpdate from 'ee/audit_events/graphql/mutations/update_group_streaming_destination.mutation.graphql';
import instanceAuditEventStreamingDestinationsUpdate from 'ee/audit_events/graphql/mutations/update_instance_streaming_destination.mutation.graphql';
import externalAuditEventDestinationUpdate from 'ee/audit_events/graphql/mutations/update_external_destination.mutation.graphql';
import instanceExternalAuditEventDestinationUpdate from 'ee/audit_events/graphql/mutations/update_instance_external_destination.mutation.graphql';
import googleCloudLoggingConfigurationUpdate from 'ee/audit_events/graphql/mutations/update_gcp_logging_destination.mutation.graphql';
import instanceGoogleCloudLoggingConfigurationUpdate from 'ee/audit_events/graphql/mutations/update_instance_gcp_logging_destination.mutation.graphql';
import amazonS3ConfigurationUpdate from 'ee/audit_events/graphql/mutations/update_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationUpdate from 'ee/audit_events/graphql/mutations/update_instance_amazon_s3_destination.mutation.graphql';

import {
  groupPath,
  instanceGroupPath,
  mockExternalDestinations,
  mockInstanceExternalDestinations,
  mockHttpType,
  mockGcpLoggingType,
  mockAmazonS3Type,
  mockAmazonS3Destinations,
} from '../../mock_data';
import { mockHttpTypeDestination } from '../../mock_data/consolidated_api';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('StreamItem', () => {
  let wrapper;
  let mutationHandlers;

  const destinationWithoutFilters = mockExternalDestinations[0];
  const destinationWithFilters = mockExternalDestinations[1];
  const instanceDestination = mockInstanceExternalDestinations[0];

  let groupPathProvide = groupPath;
  let itemProps = destinationWithoutFilters;
  let typeProps = mockHttpType;

  beforeEach(() => {
    mutationHandlers = {
      groupStreamingUpdate: jest.fn(),
      instanceStreamingUpdate: jest.fn(),
      externalDestinationUpdate: jest.fn(),
      instanceExternalUpdate: jest.fn(),
      gcpLoggingUpdate: jest.fn(),
      instanceGcpLoggingUpdate: jest.fn(),
      amazonS3Update: jest.fn(),
      instanceAmazonS3Update: jest.fn(),
    };
  });

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [groupAuditEventStreamingDestinationsUpdate, mutationHandlers.groupStreamingUpdate],
      [instanceAuditEventStreamingDestinationsUpdate, mutationHandlers.instanceStreamingUpdate],
      [externalAuditEventDestinationUpdate, mutationHandlers.externalDestinationUpdate],
      [instanceExternalAuditEventDestinationUpdate, mutationHandlers.instanceExternalUpdate],
      [googleCloudLoggingConfigurationUpdate, mutationHandlers.gcpLoggingUpdate],
      [instanceGoogleCloudLoggingConfigurationUpdate, mutationHandlers.instanceGcpLoggingUpdate],
      [amazonS3ConfigurationUpdate, mutationHandlers.amazonS3Update],
      [instanceAmazonS3ConfigurationUpdate, mutationHandlers.instanceAmazonS3Update],
    ]);

    wrapper = mountExtended(StreamItem, {
      propsData: {
        item: itemProps,
        type: typeProps,
        ...props,
      },
      provide: {
        groupPath: groupPathProvide,
        ...provide,
      },
      apolloProvider,
      stubs: {
        StreamDestinationEditor: true,
        StreamHttpDestinationEditor: true,
        StreamGcpLoggingDestinationEditor: true,
        StreamAmazonS3DestinationEditor: true,
      },
    });
  };

  const findToggleButton = () => wrapper.findByTestId('toggle-btn');
  const findToggle = () => wrapper.findComponent(GlToggle);
  const findStreamDestinationEditor = () => wrapper.findComponent(StreamDestinationEditor);
  const findStreamHttpDestinationEditor = () => wrapper.findComponent(StreamHttpDestinationEditor);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findGcpLoggingEditor = () => wrapper.findComponent(StreamGcpLoggingDestinationEditor);
  const findAmazonS3Editor = () => wrapper.findComponent(StreamAmazonS3DestinationEditor);
  const findFilterBadge = () => wrapper.findByTestId('filter-badge');

  describe('when useConsolidatedAuditEventStreamDestApi is enabled', () => {
    beforeEach(async () => {
      createComponent({
        props: { item: mockHttpTypeDestination[0] },
        provide: {
          glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
        },
      });
      await findToggleButton().vm.$emit('click');
    });

    it('should pass the item to the editor', () => {
      expect(findStreamDestinationEditor().props('item')).toStrictEqual(mockHttpTypeDestination[0]);
    });

    describe('active toggle', () => {
      it('renders toggle with correct state', () => {
        createComponent({
          props: { item: mockHttpTypeDestination[0] },
          provide: {
            glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
          },
        });

        expect(findToggle().exists()).toBe(true);
        expect(findToggle().props('value')).toBe(true);
        expect(findToggle().props('label')).toBe('Active');
      });

      it('calls consolidated API mutation for group destinations', async () => {
        createComponent({
          props: { item: mockHttpTypeDestination[0] },
          provide: {
            glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
          },
        });

        mutationHandlers.groupStreamingUpdate.mockResolvedValue({
          data: {
            groupAuditEventStreamingDestinationsUpdate: {
              errors: [],
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.groupStreamingUpdate).toHaveBeenCalledWith({
          input: expect.objectContaining({
            id: mockHttpTypeDestination[0].id,
            name: mockHttpTypeDestination[0].name,
            active: false,
            config: expect.any(Object),
          }),
        });
      });

      it('calls instance consolidated API mutation for instance destinations', async () => {
        createComponent({
          props: {
            item: {
              ...mockHttpTypeDestination[0],
              __typename: 'InstanceAuditEventStreamingDestination',
            },
          },
          provide: {
            groupPath: instanceGroupPath,
            glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
          },
        });

        mutationHandlers.instanceStreamingUpdate.mockResolvedValue({
          data: {
            instanceAuditEventStreamingDestinationsUpdate: {
              errors: [],
            },
          },
        });

        await findToggle().vm.$emit('change', true);
        await waitForPromises();

        expect(mutationHandlers.instanceStreamingUpdate).toHaveBeenCalledWith({
          input: expect.objectContaining({
            active: true,
          }),
        });
      });
    });
  });

  describe('Group http StreamItem', () => {
    describe('render', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not render the editor', () => {
        expect(findStreamHttpDestinationEditor().isVisible()).toBe(false);
      });

      it('renders toggle with active state', () => {
        expect(findToggle().exists()).toBe(true);
        expect(findToggle().props('value')).toBe(true);
        expect(findToggle().props('label')).toBe('Active');
      });

      it('renders toggle with inactive state', () => {
        createComponent({
          props: {
            item: { ...destinationWithoutFilters, active: false },
          },
        });

        expect(findToggle().props('value')).toBe(false);
        expect(findToggle().props('label')).toBe('Inactive');
      });

      it('applies opacity class when destination is inactive', () => {
        createComponent({
          props: {
            item: { ...destinationWithoutFilters, active: false },
          },
        });

        expect(findToggleButton().classes()).toContain('gl-opacity-60');
      });

      it('does not apply opacity class when destination is active', () => {
        expect(findToggleButton().classes()).not.toContain('gl-opacity-60');
      });
    });

    describe('deleting', () => {
      const id = 1;

      it('bubbles up the "deleted" event', async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');

        findStreamHttpDestinationEditor().vm.$emit('deleted', id);

        expect(wrapper.emitted('deleted')).toEqual([[id]]);
      });
    });

    describe('editing', () => {
      beforeEach(async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');
      });

      it('should pass the item to the editor', () => {
        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
        expect(findStreamHttpDestinationEditor().props('item')).toStrictEqual(
          mockExternalDestinations[0],
        );
      });

      it('should emit the updated event and show success message when the editor fires its update event', async () => {
        await findStreamHttpDestinationEditor().vm.$emit('updated');

        expect(findAlert().text()).toBe(UPDATE_STREAM_MESSAGE);
        expect(wrapper.emitted('updated')).toBeDefined();
        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
      });

      it('should emit the error event when the editor fires its error event', () => {
        findStreamHttpDestinationEditor().vm.$emit('error');

        expect(wrapper.emitted('error')).toBeDefined();
        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
      });

      it('should close the editor when the editor fires its cancel event', async () => {
        findStreamHttpDestinationEditor().vm.$emit('cancel');
        await waitForPromises();

        expect(findStreamHttpDestinationEditor().isVisible()).toBe(false);
      });

      it('clears success message when closing', async () => {
        await findStreamHttpDestinationEditor().vm.$emit('updated');
        await findToggleButton().vm.$emit('click');

        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('active toggle', () => {
      it('successfully toggles destination to inactive', async () => {
        createComponent();

        mutationHandlers.externalDestinationUpdate.mockResolvedValue({
          data: {
            externalAuditEventDestinationUpdate: {
              errors: [],
              externalAuditEventDestination: {
                ...destinationWithoutFilters,
                active: false,
              },
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.externalDestinationUpdate).toHaveBeenCalledWith({
          id: destinationWithoutFilters.id,
          name: destinationWithoutFilters.name,
          active: false,
        });

        const emitted = wrapper.emitted();
        if (emitted.updated) {
          expect(emitted.updated).toHaveLength(1);
        }

        const alert = findAlert();
        if (alert.exists()) {
          expect(alert.text()).toBe('Destination deactivated successfully.');
        }
      });

      it('successfully toggles destination to active', async () => {
        createComponent({
          props: {
            item: { ...destinationWithoutFilters, active: false },
          },
        });

        mutationHandlers.externalDestinationUpdate.mockResolvedValue({
          data: {
            externalAuditEventDestinationUpdate: {
              errors: [],
              externalAuditEventDestination: {
                ...destinationWithoutFilters,
                active: true,
              },
            },
          },
        });

        await findToggle().vm.$emit('change', true);
        await waitForPromises();

        const emitted = wrapper.emitted();
        if (emitted.updated) {
          expect(emitted.updated).toHaveLength(1);
        }

        const alert = findAlert();
        if (alert.exists()) {
          expect(alert.text()).toBe('Destination activated successfully.');
        }
      });

      it('handles GraphQL mutation errors', async () => {
        createComponent();

        mutationHandlers.externalDestinationUpdate.mockResolvedValue({
          data: {
            externalAuditEventDestinationUpdate: {
              errors: ['Something went wrong'],
              externalAuditEventDestination: null,
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalled();
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to update destination status. Please try again.',
          captureError: true,
          error: expect.any(Error),
        });
      });

      it('handles network errors', async () => {
        createComponent();

        const error = new Error('Network error');
        mutationHandlers.externalDestinationUpdate.mockRejectedValue(error);

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith(error);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to update destination status. Please try again.',
          captureError: true,
          error,
        });
      });

      it('shows loading state during toggle operation', async () => {
        createComponent();

        mutationHandlers.externalDestinationUpdate.mockImplementation(() => new Promise(() => {}));

        await findToggle().vm.$emit('change', false);

        expect(findToggle().props('isLoading')).toBe(true);
        expect(findToggle().props('disabled')).toBe(true);
      });
    });

    describe('when an item has event filters', () => {
      beforeEach(() => {
        createComponent({ props: { item: destinationWithFilters } });
      });

      it('should show filter badge', () => {
        expect(findFilterBadge().text()).toBe(STREAM_ITEMS_I18N.FILTER_BADGE_LABEL);
        expect(findFilterBadge().attributes('id')).toBe(destinationWithFilters.id);
      });

      it('renders a popover', () => {
        expect(wrapper.findByTestId('filter-popover').element).toMatchSnapshot();
      });
    });

    describe('when an item has namespace filters', () => {
      beforeEach(() => {
        createComponent({ props: { item: destinationWithFilters } });
      });

      it('should show filter badge', () => {
        expect(findFilterBadge().text()).toBe(STREAM_ITEMS_I18N.FILTER_BADGE_LABEL);
        expect(findFilterBadge().attributes('id')).toBe(destinationWithFilters.id);
      });

      it('renders a popover', () => {
        expect(wrapper.findByTestId('filter-popover').element).toMatchSnapshot();
      });
    });

    describe('when an item has no filter', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not show filter badge', () => {
        expect(findFilterBadge().exists()).toBe(false);
      });
    });

    describe('state synchronization', () => {
      it('updates local state when item.active prop changes', async () => {
        createComponent();

        expect(findToggle().props('value')).toBe(true);

        await wrapper.setProps({
          item: { ...destinationWithoutFilters, active: false },
        });

        expect(findToggle().props('value')).toBe(false);
      });
    });
  });

  describe('Group gcp logging StreamItem', () => {
    beforeEach(() => {
      typeProps = mockGcpLoggingType;
      itemProps = {
        id: 'test_id1',
        name: 'Name',
        googleProjectIdName: 'test-project',
        clientEmail: 'test@example.com',
        logIdName: 'audit_events',
        active: true,
      };
    });

    describe('render', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not render the editor', () => {
        expect(findGcpLoggingEditor().isVisible()).toBe(false);
      });

      it('renders toggle with correct state', () => {
        expect(findToggle().exists()).toBe(true);
        expect(findToggle().props('value')).toBe(true);
      });
    });

    describe('deleting', () => {
      const id = 1;

      it('bubbles up the "deleted" event', async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');

        findGcpLoggingEditor().vm.$emit('deleted', id);

        expect(wrapper.emitted('deleted')).toEqual([[id]]);
      });
    });

    describe('editing', () => {
      beforeEach(async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');
      });

      it('should pass the item to the editor', () => {
        expect(findGcpLoggingEditor().exists()).toBe(true);
        expect(findGcpLoggingEditor().props('item')).toStrictEqual(itemProps);
      });

      it('should emit the updated event and show success message when the editor fires its update event', async () => {
        await findGcpLoggingEditor().vm.$emit('updated');

        expect(wrapper.emitted('updated')).toBeDefined();
        expect(findAlert().text()).toBe(UPDATE_STREAM_MESSAGE);
        expect(findGcpLoggingEditor().exists()).toBe(true);
      });

      it('should emit the error event when the editor fires its error event', () => {
        findGcpLoggingEditor().vm.$emit('error');

        expect(wrapper.emitted('error')).toBeDefined();
        expect(findGcpLoggingEditor().exists()).toBe(true);
      });

      it('should close the editor when the editor fires its cancel event', async () => {
        findGcpLoggingEditor().vm.$emit('cancel');
        await waitForPromises();

        expect(findGcpLoggingEditor().isVisible()).toBe(false);
      });

      it('clears success message when closing', async () => {
        await findGcpLoggingEditor().vm.$emit('updated');
        await findToggleButton().vm.$emit('click');

        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('active toggle', () => {
      it('handles GCP Logging destination toggle', async () => {
        createComponent();

        mutationHandlers.gcpLoggingUpdate.mockResolvedValue({
          data: {
            auditEventsGoogleCloudLoggingConfigurationUpdate: {
              errors: [],
              googleCloudLoggingConfiguration: {
                ...itemProps,
                active: false,
              },
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.gcpLoggingUpdate).toHaveBeenCalledWith({
          id: itemProps.id,
          name: itemProps.name,
          active: false,
          logIdName: expect.any(String),
          googleProjectIdName: expect.any(String),
          clientEmail: expect.any(String),
        });
      });

      it('handles errors for GCP Logging destinations', async () => {
        createComponent();

        const error = new Error('GCP error');
        mutationHandlers.gcpLoggingUpdate.mockRejectedValue(error);

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith(error);
        expect(createAlert).toHaveBeenCalled();
      });
    });
  });

  describe('Group Amazon S3 StreamItem', () => {
    beforeEach(() => {
      typeProps = mockAmazonS3Type;
      [itemProps] = mockAmazonS3Destinations;
    });

    describe('render', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not render the editor', () => {
        expect(findAmazonS3Editor().isVisible()).toBe(false);
      });

      it('renders toggle', () => {
        expect(findToggle().exists()).toBe(true);
      });
    });

    describe('deleting', () => {
      const id = 1;

      it('bubbles up the "deleted" event', async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');

        findAmazonS3Editor().vm.$emit('deleted', id);

        expect(wrapper.emitted('deleted')).toEqual([[id]]);
      });
    });

    describe('editing', () => {
      beforeEach(async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');
      });

      it('should pass the item to the editor', () => {
        expect(findAmazonS3Editor().exists()).toBe(true);
        expect(findAmazonS3Editor().props('item')).toStrictEqual(itemProps);
      });

      it('should emit the updated event and show success message when the editor fires its update event', async () => {
        await findAmazonS3Editor().vm.$emit('updated');

        expect(wrapper.emitted('updated')).toBeDefined();
        expect(findAlert().text()).toBe(UPDATE_STREAM_MESSAGE);
        expect(findAmazonS3Editor().exists()).toBe(true);
      });

      it('should emit the error event when the editor fires its error event', () => {
        findAmazonS3Editor().vm.$emit('error');

        expect(wrapper.emitted('error')).toBeDefined();
        expect(findAmazonS3Editor().exists()).toBe(true);
      });

      it('should close the editor when the editor fires its cancel event', async () => {
        findAmazonS3Editor().vm.$emit('cancel');
        await waitForPromises();

        expect(findAmazonS3Editor().isVisible()).toBe(false);
      });

      it('clears success message when closing', async () => {
        await findAmazonS3Editor().vm.$emit('updated');
        await findToggleButton().vm.$emit('click');

        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('active toggle', () => {
      it('handles Amazon S3 destination toggle', async () => {
        createComponent();

        mutationHandlers.amazonS3Update.mockResolvedValue({
          data: {
            auditEventsAmazonS3ConfigurationUpdate: {
              errors: [],
              amazonS3Configuration: {
                ...itemProps,
                active: false,
              },
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.amazonS3Update).toHaveBeenCalledWith({
          id: itemProps.id,
          name: itemProps.name,
          active: false,
          fullPath: groupPath,
          bucketName: expect.any(String),
          awsRegion: expect.any(String),
          accessKeyXid: expect.any(String),
        });
      });
    });
  });

  describe('Instance StreamItem', () => {
    beforeEach(() => {
      groupPathProvide = instanceGroupPath;
      itemProps = instanceDestination;
      typeProps = mockHttpType;
    });

    describe('render', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not render the editor', () => {
        expect(findStreamHttpDestinationEditor().isVisible()).toBe(false);
      });

      it('renders toggle', () => {
        expect(findToggle().exists()).toBe(true);
      });
    });

    describe('deleting', () => {
      const id = 1;

      it('bubbles up the "deleted" event', async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');

        findStreamHttpDestinationEditor().vm.$emit('deleted', id);

        expect(wrapper.emitted('deleted')).toEqual([[id]]);
      });
    });

    describe('editing', () => {
      beforeEach(async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');
      });

      it('should pass the item to the editor', () => {
        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
        expect(findStreamHttpDestinationEditor().props('item')).toStrictEqual(
          mockInstanceExternalDestinations[0],
        );
      });

      it('should emit the updated event and show success message when the editor fires its update event', async () => {
        await findStreamHttpDestinationEditor().vm.$emit('updated');

        expect(findAlert().text()).toBe(UPDATE_STREAM_MESSAGE);
        expect(wrapper.emitted('updated')).toBeDefined();
        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
      });

      it('should emit the error event when the editor fires its error event', () => {
        findStreamHttpDestinationEditor().vm.$emit('error');

        expect(wrapper.emitted('error')).toBeDefined();
        expect(findStreamHttpDestinationEditor().exists()).toBe(true);
      });

      it('should close the editor when the editor fires its cancel event', async () => {
        findStreamHttpDestinationEditor().vm.$emit('cancel');
        await waitForPromises();

        expect(findStreamHttpDestinationEditor().isVisible()).toBe(false);
      });

      it('clears success message when closing', async () => {
        await findStreamHttpDestinationEditor().vm.$emit('updated');
        await findToggleButton().vm.$emit('click');

        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('active toggle', () => {
      it('toggles instance destination active state', async () => {
        createComponent();

        mutationHandlers.instanceExternalUpdate.mockResolvedValue({
          data: {
            instanceExternalAuditEventDestinationUpdate: {
              errors: [],
              instanceExternalAuditEventDestination: {
                ...instanceDestination,
                active: false,
              },
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.instanceExternalUpdate).toHaveBeenCalledWith({
          id: instanceDestination.id,
          name: instanceDestination.name,
          active: false,
        });
      });

      it('handles instance GCP Logging destinations', async () => {
        typeProps = mockGcpLoggingType;
        createComponent();

        mutationHandlers.instanceGcpLoggingUpdate.mockResolvedValue({
          data: {
            instanceGoogleCloudLoggingConfigurationUpdate: {
              errors: [],
              instanceGoogleCloudLoggingConfiguration: {
                ...instanceDestination,
                active: false,
              },
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.instanceGcpLoggingUpdate).toHaveBeenCalled();
      });

      it('handles instance Amazon S3 destinations', async () => {
        typeProps = mockAmazonS3Type;
        createComponent();

        mutationHandlers.instanceAmazonS3Update.mockResolvedValue({
          data: {
            auditEventsInstanceAmazonS3ConfigurationUpdate: {
              errors: [],
              instanceAmazonS3Configuration: {
                ...instanceDestination,
                active: false,
              },
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.instanceAmazonS3Update).toHaveBeenCalled();
      });
    });

    describe('when an item has no filter', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not show filter badge', () => {
        expect(findFilterBadge().exists()).toBe(false);
      });
    });
  });
});
