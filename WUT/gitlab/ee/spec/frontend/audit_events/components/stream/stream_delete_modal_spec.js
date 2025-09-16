import { GlSprintf, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import StreamDeleteModal from 'ee/audit_events/components/stream/stream_delete_modal.vue';
import deleteGroupStreamingDestinationsQuery from 'ee/audit_events/graphql/mutations/delete_group_streaming_destination.mutation.graphql';
import deleteExternalDestination from 'ee/audit_events/graphql/mutations/delete_external_destination.mutation.graphql';
import deleteInstanceExternalDestination from 'ee/audit_events/graphql/mutations/delete_instance_external_destination.mutation.graphql';
import googleCloudLoggingConfigurationDestroy from 'ee/audit_events/graphql/mutations/delete_gcp_logging_destination.mutation.graphql';
import instanceGoogleCloudLoggingConfigurationDestroy from 'ee/audit_events/graphql/mutations/delete_instance_gcp_logging_destination.mutation.graphql';
import amazonS3ConfigurationDestroy from 'ee/audit_events/graphql/mutations/delete_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationDestroy from 'ee/audit_events/graphql/mutations/delete_instance_amazon_s3_destination.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  groupPath,
  destinationDeleteMutationPopulator,
  mockExternalDestinations,
  mockHttpType,
  mockGcpLoggingType,
  instanceGroupPath,
  destinationInstanceDeleteMutationPopulator,
  mockInstanceExternalDestinations,
  mockGcpLoggingDestinations,
  destinationGcpLoggingDeleteMutationPopulator,
  mockInstanceGcpLoggingDestinations,
  destinationInstanceGcpLoggingDeleteMutationPopulator,
  mockAmazonS3Destinations,
  mockAmazonS3Type,
  destinationAmazonS3DeleteMutationPopulator,
  mockInstanceAmazonS3Destinations,
  destinationInstanceAmazonS3DeleteMutationPopulator,
} from '../../mock_data';
import {
  mockHttpTypeDestination,
  streamingDestinationDeleteMutationPopulator,
} from '../../mock_data/consolidated_api';

Vue.use(VueApollo);

describe('StreamDeleteModal', () => {
  let wrapper;

  const instanceDestination = mockInstanceExternalDestinations[0];
  const gcpLoggingDestination = mockGcpLoggingDestinations[0];
  const instanceGcpLoggingDestination = mockInstanceGcpLoggingDestinations[0];
  const mockAmazonS3Destination = mockAmazonS3Destinations[0];
  const instanceAmazonS3Destination = mockInstanceAmazonS3Destinations[0];

  const deleteStreamingSuccess = jest
    .fn()
    .mockResolvedValue(streamingDestinationDeleteMutationPopulator());
  const deleteStreamingError = jest
    .fn()
    .mockResolvedValue(streamingDestinationDeleteMutationPopulator(['Random Error message']));
  const deleteStreamingNetworkError = jest
    .fn()
    .mockRejectedValue(streamingDestinationDeleteMutationPopulator(['Network error']));

  const deleteSuccess = jest.fn().mockResolvedValue(destinationDeleteMutationPopulator());
  const deleteInstanceSuccess = jest
    .fn()
    .mockResolvedValue(destinationInstanceDeleteMutationPopulator());
  const deleteGcpLoggingSuccess = jest
    .fn()
    .mockResolvedValue(destinationGcpLoggingDeleteMutationPopulator());
  const deleteInstanceGcpLoggingSuccess = jest
    .fn()
    .mockResolvedValue(destinationInstanceGcpLoggingDeleteMutationPopulator());
  const deleteAmazonS3Success = jest
    .fn()
    .mockResolvedValue(destinationAmazonS3DeleteMutationPopulator());
  const deleteInstanceAmazonS3Success = jest
    .fn()
    .mockResolvedValue(destinationInstanceAmazonS3DeleteMutationPopulator());
  const deleteError = jest
    .fn()
    .mockResolvedValue(destinationDeleteMutationPopulator(['Random Error message']));
  const deleteNetworkError = jest
    .fn()
    .mockRejectedValue(destinationDeleteMutationPopulator(['Network error']));

  let groupPathProvide = groupPath;
  let itemProvide = mockExternalDestinations[0];
  let typeProvide = mockHttpType;
  let deleteExternalDestinationProvide = deleteExternalDestination;

  const findModal = () => wrapper.findComponent(GlModal);
  const clickDeleteFramework = () => findModal().vm.$emit('primary');

  const createComponent = (resolverMock, useConsolidatedAuditEventStreamDestApi = false) => {
    const mockApollo = createMockApollo([[deleteExternalDestinationProvide, resolverMock]]);

    wrapper = shallowMount(StreamDeleteModal, {
      apolloProvider: mockApollo,
      propsData: {
        item: itemProvide,
        type: typeProvide,
      },
      provide: {
        groupPath: groupPathProvide,
        glFeatures: {
          useConsolidatedAuditEventStreamDestApi,
        },
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('component layout', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets the modal id', () => {
      expect(findModal().props('modalId')).toBe('delete-destination-modal');
    });

    it('sets the modal primary button attributes', () => {
      const actionPrimary = findModal().props('actionPrimary');

      expect(actionPrimary.text).toBe('Delete destination');
      expect(actionPrimary.attributes.variant).toBe('danger');
    });

    it('sets the modal cancel button attributes', () => {
      expect(findModal().props('actionCancel').text).toBe('Cancel');
    });
  });

  describe('Group HTTP clickDeleteDestination', () => {
    it('emits "deleting" event when busy deleting', () => {
      createComponent();
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    it('calls the delete mutation with the destination ID', async () => {
      createComponent(deleteSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(deleteSuccess).toHaveBeenCalledWith({
        id: mockExternalDestinations[0].id,
        isInstance: false,
      });
    });

    it('emits "delete" event when the destination is successfully deleted', async () => {
      createComponent(deleteSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    it('emits "error" event when there is a network error', async () => {
      createComponent(deleteNetworkError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits "error" event when there is a graphql error', async () => {
      createComponent(deleteError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
    describe('with useConsolidatedAuditEventStreamDestApi feature flag', () => {
      beforeEach(() => {
        deleteExternalDestinationProvide = deleteGroupStreamingDestinationsQuery;
        [itemProvide] = mockHttpTypeDestination;
      });

      it('calls the delete mutation with the destination ID', async () => {
        createComponent(deleteStreamingSuccess, true);
        clickDeleteFramework();

        await waitForPromises();

        expect(deleteStreamingSuccess).toHaveBeenCalledWith({
          id: mockHttpTypeDestination[0].id,
          isInstance: false,
        });
      });

      it('emits "delete" event when the destination is successfully deleted', async () => {
        createComponent(deleteStreamingSuccess, true);
        clickDeleteFramework();

        await waitForPromises();

        expect(wrapper.emitted('delete')).toHaveLength(1);
      });

      it('emits "error" event when there is a network error', async () => {
        createComponent(deleteStreamingNetworkError, true);
        clickDeleteFramework();

        await waitForPromises();

        expect(wrapper.emitted('error')).toHaveLength(1);
      });

      it('emits "error" event when there is a graphql error', async () => {
        createComponent(deleteStreamingError, true);
        clickDeleteFramework();

        await waitForPromises();

        expect(wrapper.emitted('error')).toHaveLength(1);
      });
    });
  });

  describe('Group GCP Logging clickDeleteDestination', () => {
    beforeEach(() => {
      itemProvide = gcpLoggingDestination;
      typeProvide = mockGcpLoggingType;
      deleteExternalDestinationProvide = googleCloudLoggingConfigurationDestroy;
    });

    it('emits "deleting" event when busy deleting', () => {
      createComponent();
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    it('calls the delete mutation with the destination ID', async () => {
      createComponent(deleteGcpLoggingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(deleteGcpLoggingSuccess).toHaveBeenCalledWith({
        id: mockGcpLoggingDestinations[0].id,
        isInstance: false,
      });
    });

    it('emits "delete" event when the destination is successfully deleted', async () => {
      createComponent(deleteGcpLoggingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    it('emits "error" event when there is a network error', async () => {
      createComponent(deleteNetworkError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits "error" event when there is a graphql error', async () => {
      createComponent(deleteError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('Group Amazon S3 clickDeleteDestination', () => {
    beforeEach(() => {
      itemProvide = mockAmazonS3Destination;
      typeProvide = mockAmazonS3Type;
      deleteExternalDestinationProvide = amazonS3ConfigurationDestroy;
    });

    it('emits "deleting" event when busy deleting', () => {
      createComponent();
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    it('calls the delete mutation with the destination ID', async () => {
      createComponent(deleteAmazonS3Success);
      clickDeleteFramework();

      await waitForPromises();

      expect(deleteAmazonS3Success).toHaveBeenCalledWith({
        id: mockAmazonS3Destinations[0].id,
        isInstance: false,
      });
    });

    it('emits "delete" event when the destination is successfully deleted', async () => {
      createComponent(deleteAmazonS3Success);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    it('emits "error" event when there is a network error', async () => {
      createComponent(deleteNetworkError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits "error" event when there is a graphql error', async () => {
      createComponent(deleteError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('Instance clickDeleteDestination', () => {
    beforeEach(() => {
      groupPathProvide = instanceGroupPath;
      itemProvide = instanceDestination;
      typeProvide = instanceGroupPath;
      deleteExternalDestinationProvide = deleteInstanceExternalDestination;
    });

    it('emits "deleting" event when busy deleting', () => {
      createComponent();
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    it('calls the delete mutation with the destination ID', async () => {
      createComponent(deleteInstanceSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(deleteInstanceSuccess).toHaveBeenCalledWith({
        id: mockExternalDestinations[0].id,
        isInstance: true,
      });
    });

    it('emits "delete" event when the destination is successfully deleted', async () => {
      createComponent(deleteInstanceSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    it('emits "error" event when there is a network error', async () => {
      createComponent(deleteNetworkError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits "error" event when there is a graphql error', async () => {
      createComponent(deleteError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('Instance GCP Logging clickDeleteDestination', () => {
    beforeEach(() => {
      groupPathProvide = instanceGroupPath;
      itemProvide = instanceGcpLoggingDestination;
      typeProvide = mockGcpLoggingType;
      deleteExternalDestinationProvide = instanceGoogleCloudLoggingConfigurationDestroy;
    });

    it('emits "deleting" event when busy deleting', () => {
      createComponent();
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    it('calls the delete mutation with the destination ID', async () => {
      createComponent(deleteInstanceGcpLoggingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(deleteInstanceGcpLoggingSuccess).toHaveBeenCalledWith({
        id: mockInstanceGcpLoggingDestinations[0].id,
        isInstance: true,
      });
    });

    it('emits "delete" event when the destination is successfully deleted', async () => {
      createComponent(deleteInstanceGcpLoggingSuccess);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('delete')).toHaveLength(1);
    });

    it('emits "error" event when there is a network error', async () => {
      createComponent(deleteNetworkError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits "error" event when there is a graphql error', async () => {
      createComponent(deleteError);
      clickDeleteFramework();

      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('Instance Amazon S3 clickDeleteDestination', () => {
    beforeEach(() => {
      groupPathProvide = instanceGroupPath;
      itemProvide = instanceAmazonS3Destination;
      typeProvide = mockAmazonS3Type;
      deleteExternalDestinationProvide = instanceAmazonS3ConfigurationDestroy;
    });

    it('emits "deleting" event when busy deleting', () => {
      createComponent();
      clickDeleteFramework();

      expect(wrapper.emitted('deleting')).toHaveLength(1);
    });

    describe('when deleting', () => {
      beforeEach(async () => {
        createComponent(deleteInstanceAmazonS3Success);
        clickDeleteFramework();

        await waitForPromises();
      });
      it('calls the delete mutation with the destination ID', () => {
        expect(deleteInstanceAmazonS3Success).toHaveBeenCalledWith({
          id: mockInstanceAmazonS3Destinations[0].id,
          isInstance: true,
        });
      });

      it('emits "delete" event when the destination is successfully deleted', () => {
        expect(wrapper.emitted('delete')).toHaveLength(1);
      });
    });

    describe.each([
      ['network error', deleteNetworkError],
      ['graphql error', deleteError],
    ])('when %p', (_, mockResolver) => {
      beforeEach(async () => {
        createComponent(mockResolver);
        clickDeleteFramework();

        await waitForPromises();
      });

      it('emits "error" event', () => {
        expect(wrapper.emitted('error')).toHaveLength(1);
      });
    });
  });
});
