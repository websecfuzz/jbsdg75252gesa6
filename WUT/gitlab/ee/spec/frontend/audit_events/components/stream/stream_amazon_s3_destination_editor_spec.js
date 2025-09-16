import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import amazonS3ConfigurationCreate from 'ee/audit_events/graphql/mutations/create_amazon_s3_destination.mutation.graphql';
import amazonS3ConfigurationUpdate from 'ee/audit_events/graphql/mutations/update_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationCreate from 'ee/audit_events/graphql/mutations/create_instance_amazon_s3_destination.mutation.graphql';
import instanceAmazonS3ConfigurationUpdate from 'ee/audit_events/graphql/mutations/update_instance_amazon_s3_destination.mutation.graphql';
import StreamAmazonS3DestinationEditor from 'ee/audit_events/components/stream/stream_amazon_s3_destination_editor.vue';
import StreamDeleteModal from 'ee/audit_events/components/stream/stream_delete_modal.vue';
import { AUDIT_STREAMS_NETWORK_ERRORS, ADD_STREAM_EDITOR_I18N } from 'ee/audit_events/constants';
import {
  amazonS3DestinationCreateMutationPopulator,
  amazonS3DestinationUpdateMutationPopulator,
  groupPath,
  instanceGroupPath,
  mockAmazonS3Destinations,
  mockInstanceAmazonS3Destinations,
  instanceAmazonS3DestinationCreateMutationPopulator,
  instanceAmazonS3DestinationUpdateMutationPopulator,
} from '../../mock_data';
import { mockAwsTypeDestination } from '../../mock_data/consolidated_api';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('StreamAmazonS3DestinationEditor', () => {
  let wrapper;
  let groupPathProvide = groupPath;

  const createComponent = ({
    mountFn = mountExtended,
    props = {},
    provide = {},
    apolloHandlers = [
      [
        amazonS3ConfigurationCreate,
        jest.fn().mockResolvedValue(amazonS3DestinationCreateMutationPopulator()),
      ],
    ],
  } = {}) => {
    const mockApollo = createMockApollo(apolloHandlers);
    wrapper = mountFn(StreamAmazonS3DestinationEditor, {
      attachTo: document.body,
      provide: {
        groupPath: groupPathProvide,
        ...provide,
      },
      propsData: {
        ...props,
      },
      apolloProvider: mockApollo,
    });
  };

  const findWarningMessage = () => wrapper.findByTestId('data-warning');
  const findAlertErrors = () => wrapper.findAllByTestId('alert-errors');
  const findDestinationForm = () => wrapper.findComponent(GlForm);
  const findSubmitStreamBtn = () => wrapper.findByTestId('stream-destination-submit-button');
  const findCancelStreamBtn = () => wrapper.findByTestId('stream-destination-cancel-button');
  const findDeleteBtn = () => wrapper.findByTestId('stream-destination-delete-button');
  const findDeleteModal = () => wrapper.findComponent(StreamDeleteModal);

  const findNameFormGroup = () => wrapper.findByTestId('name-form-group');
  const findName = () => wrapper.findByTestId('name');
  const findAccessKeyXidFormGroup = () => wrapper.findByTestId('access-key-xid-form-group');
  const findAccessKeyXid = () => wrapper.findByTestId('access-key-xid');
  const findAwsRegionFormGroup = () => wrapper.findByTestId('aws-region-form-group');
  const findAwsRegion = () => wrapper.findByTestId('aws-region');
  const findBucketNameFormGroup = () => wrapper.findByTestId('bucket-name-form-group');
  const findBucketName = () => wrapper.findByTestId('bucket-name');
  const findSecretAccessKeyFormGroup = () => wrapper.findByTestId('secret-access-key-form-group');
  const findSecretAccessKey = () => wrapper.findByTestId('secret-access-key');
  const findSecretAccessKeyAddButton = () => wrapper.findByTestId('secret-access-key-add-button');
  const findSecretAccessKeyCancelButton = () =>
    wrapper.findByTestId('secret-access-key-cancel-button');

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('when useConsolidatedAuditEventStreamDestApi is enabled', () => {
    const item = mockAwsTypeDestination[0];

    beforeEach(() => {
      createComponent({
        props: { item },
        provide: {
          glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
        },
      });
    });

    it('renders the destination correctly', () => {
      expect(findName().element.value).toBe('AWS Destination 1');
      expect(findAccessKeyXid().element.value).toBe('myAwsAccessKey_needs_16_chars_min');
      expect(findAwsRegion().element.value).toBe('us-test-1');
      expect(findBucketName().element.value).toBe('bucket-name');
      expect(findSecretAccessKey().exists()).toBe(false);
      expect(findSecretAccessKeyAddButton().exists()).toBe(true);
      expect(findSecretAccessKeyCancelButton().exists()).toBe(false);
    });
  });

  describe('Group amazon S3 stream destination editor', () => {
    describe('when initialized', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should render the destinations warning', () => {
        expect(findWarningMessage().props('title')).toBe(ADD_STREAM_EDITOR_I18N.WARNING_TITLE);
      });

      it('should render the destination name input', () => {
        expect(findNameFormGroup().exists()).toBe(true);
        expect(findName().exists()).toBe(true);
        expect(findName().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_NAME_PLACEHOLDER,
        );
      });

      it('should render the destination AccessKeyXid input', () => {
        expect(findAccessKeyXidFormGroup().exists()).toBe(true);
        expect(findAccessKeyXid().exists()).toBe(true);
        expect(findAccessKeyXid().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_ACCESS_KEY_XID_PLACEHOLDER,
        );
      });

      it('should render the destination awsRegion input', () => {
        expect(findAwsRegionFormGroup().exists()).toBe(true);
        expect(findAwsRegion().exists()).toBe(true);
        expect(findAwsRegion().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_AWS_REGION_PLACEHOLDER,
        );
      });

      it('should render the destination BucketName input', () => {
        expect(findBucketNameFormGroup().exists()).toBe(true);
        expect(findBucketName().exists()).toBe(true);
        expect(findBucketName().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_BUCKET_NAME_PLACEHOLDER,
        );
      });

      it('should not render the destination Secret Access Key input', () => {
        expect(findSecretAccessKeyFormGroup().exists()).toBe(true);
        expect(findSecretAccessKey().exists()).toBe(true);
      });

      it('does not render the delete button', () => {
        expect(findDeleteBtn().exists()).toBe(false);
      });

      it('renders the add button text', () => {
        expect(findSubmitStreamBtn().attributes('name')).toBe(
          ADD_STREAM_EDITOR_I18N.ADD_BUTTON_NAME,
        );
        expect(findSubmitStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.ADD_BUTTON_TEXT);
      });

      it('disables the add button at first', () => {
        expect(findSubmitStreamBtn().props('disabled')).toBe(true);
      });
    });

    describe('add destination event', () => {
      it('should emit add event after destination added', async () => {
        createComponent();

        await findName().setValue(mockAmazonS3Destinations[0].name);
        await findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        await findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        await findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        await findSecretAccessKey().setValue(mockAmazonS3Destinations[0].secretAccessKey);

        expect(findSubmitStreamBtn().props('disabled')).toBe(false);

        await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('added')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          apolloHandlers: [
            [
              amazonS3ConfigurationCreate,
              jest.fn().mockResolvedValue(amazonS3DestinationCreateMutationPopulator([errorMsg])),
            ],
          ],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findSecretAccessKey().setValue(mockAmazonS3Destinations[0].secretAccessKey);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(errorMsg);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });

      it('should not emit add destination event and reports error when network error occurs', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          apolloHandlers: [[amazonS3ConfigurationCreate, jest.fn().mockRejectedValue(sentryError)]],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findSecretAccessKey().setValue(mockAmazonS3Destinations[0].secretAccessKey);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.CREATING_ERROR);
        expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });
    });

    describe('cancel event', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should emit cancel event correctly', () => {
        findCancelStreamBtn().vm.$emit('click');

        expect(wrapper.emitted('cancel')).toBeDefined();
      });
    });

    describe('when editing an existing destination', () => {
      describe('renders', () => {
        beforeEach(() => {
          createComponent({ props: { item: mockAmazonS3Destinations[0] } });
        });

        it('the destination fields', () => {
          expect(findName().element.value).toBe(mockAmazonS3Destinations[0].name);
          expect(findAccessKeyXid().element.value).toBe(mockAmazonS3Destinations[0].accessKeyXid);
          expect(findAwsRegion().element.value).toBe(mockAmazonS3Destinations[0].awsRegion);
          expect(findBucketName().element.value).toBe(mockAmazonS3Destinations[0].bucketName);
          expect(findSecretAccessKey().exists()).toBe(false);
          expect(findSecretAccessKeyAddButton().exists()).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(false);
        });

        it('the delete button', () => {
          expect(findDeleteBtn().exists()).toBe(true);
        });

        it('renders the save button text', () => {
          expect(findSubmitStreamBtn().attributes('name')).toBe(
            ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_NAME,
          );
          expect(findSubmitStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_TEXT);
        });

        it('disables the save button at first', () => {
          expect(findSubmitStreamBtn().props('disabled')).toBe(true);
        });

        it('displays the secret access key field when adding', async () => {
          await findSecretAccessKeyAddButton().trigger('click');

          expect(findSecretAccessKeyAddButton().props('disabled')).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(true);
          expect(findSecretAccessKey().element.value).toBe('');
        });

        it('removes the secret access key field when cancelled', async () => {
          await findSecretAccessKeyAddButton().trigger('click');
          await findSecretAccessKeyCancelButton().trigger('click');

          expect(findSecretAccessKeyAddButton().props('disabled')).toBe(false);
          expect(findSecretAccessKey().exists()).toBe(false);
          expect(findSecretAccessKeyAddButton().exists()).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(false);
        });
      });

      it.each`
        name                  | findInputFn
        ${'Destination Name'} | ${findName}
        ${'Access Key Xid'}   | ${findAccessKeyXid}
        ${'AWS Region'}       | ${findAwsRegion}
        ${'Bucket Name'}      | ${findBucketName}
      `('enable the save button when $name is edited', async ({ findInputFn }) => {
        createComponent({ props: { item: mockAmazonS3Destinations[0] } });

        expect(findSubmitStreamBtn().props('disabled')).toBe(true);

        await findInputFn().setValue('test');

        expect(findSubmitStreamBtn().props('disabled')).toBe(false);
      });

      it('should emit updated event after destination updated', async () => {
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [
            [
              amazonS3ConfigurationUpdate,
              jest.fn().mockResolvedValue(amazonS3DestinationUpdateMutationPopulator()),
            ],
          ],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[1].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[1].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[1].bucketName);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('updated')).toBeDefined();
      });

      it('should emit updated event after destination secret access key updated', async () => {
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [
            [
              amazonS3ConfigurationUpdate,
              jest.fn().mockResolvedValue(amazonS3DestinationUpdateMutationPopulator()),
            ],
          ],
        });

        await findSecretAccessKeyAddButton().trigger('click');

        findSecretAccessKey().setValue(mockAmazonS3Destinations[1].secretAccessKey);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('updated')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [
            [
              amazonS3ConfigurationUpdate,
              jest.fn().mockResolvedValue(amazonS3DestinationUpdateMutationPopulator([errorMsg])),
            ],
          ],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(errorMsg);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('updated')).toBeUndefined();
      });

      it('should not emit add destination event and reports error when network error occurs', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          props: { item: mockAmazonS3Destinations[0] },
          apolloHandlers: [[amazonS3ConfigurationUpdate, jest.fn().mockRejectedValue(sentryError)]],
        });

        findName().setValue(mockAmazonS3Destinations[0].name);
        findAccessKeyXid().setValue(mockAmazonS3Destinations[0].accessKeyXid);
        findAwsRegion().setValue(mockAmazonS3Destinations[0].awsRegion);
        findBucketName().setValue(mockAmazonS3Destinations[0].bucketName);
        findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
        expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('updated')).toBeUndefined();
      });
    });

    describe('deleting', () => {
      beforeEach(() => {
        createComponent({ props: { item: mockAmazonS3Destinations[0] } });
      });

      it('should emit deleted on success operation', async () => {
        const deleteButton = findDeleteBtn();
        await deleteButton.trigger('click');
        await findDeleteModal().vm.$emit('deleting');

        expect(deleteButton.props('loading')).toBe(true);

        await findDeleteModal().vm.$emit('delete');

        expect(deleteButton.props('loading')).toBe(false);
        expect(wrapper.emitted('deleted')).toEqual([[mockAmazonS3Destinations[0].id]]);
      });

      it('shows the alert for the error', () => {
        const errorMsg = 'An error occurred';
        findDeleteModal().vm.$emit('error', errorMsg);

        expect(createAlert).toHaveBeenCalledWith({
          message: AUDIT_STREAMS_NETWORK_ERRORS.DELETING_ERROR,
          captureError: true,
          error: errorMsg,
        });
      });
    });

    it('passes actual newlines when these are used in the secret access key input', async () => {
      const mutationMock = jest
        .fn()
        .mockResolvedValue(amazonS3DestinationCreateMutationPopulator());
      createComponent({
        apolloHandlers: [[amazonS3ConfigurationCreate, mutationMock]],
      });

      await findSecretAccessKey().setValue('\\ntest\\n');
      await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });

      expect(mutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          secretAccessKey: '\ntest\n',
        }),
      );
    });
  });

  describe('Instance amazon S3 stream destination editor', () => {
    beforeEach(() => {
      groupPathProvide = instanceGroupPath;
    });

    describe('when initialized', () => {
      beforeEach(() => {
        createComponent({
          apolloHandlers: [
            [
              instanceAmazonS3ConfigurationCreate,
              jest.fn().mockResolvedValue(instanceAmazonS3DestinationCreateMutationPopulator()),
            ],
          ],
        });
      });

      it('should render the destinations warning', () => {
        expect(findWarningMessage().props('title')).toBe(ADD_STREAM_EDITOR_I18N.WARNING_TITLE);
      });

      it('should render the destination name input', () => {
        expect(findNameFormGroup().exists()).toBe(true);
        expect(findName().exists()).toBe(true);
        expect(findName().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_NAME_PLACEHOLDER,
        );
      });

      it('should render the destination AccessKeyXid input', () => {
        expect(findAccessKeyXidFormGroup().exists()).toBe(true);
        expect(findAccessKeyXid().exists()).toBe(true);
        expect(findAccessKeyXid().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_ACCESS_KEY_XID_PLACEHOLDER,
        );
      });

      it('should render the destination awsRegion input', () => {
        expect(findAwsRegionFormGroup().exists()).toBe(true);
        expect(findAwsRegion().exists()).toBe(true);
        expect(findAwsRegion().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_AWS_REGION_PLACEHOLDER,
        );
      });

      it('should render the destination BucketName input', () => {
        expect(findBucketNameFormGroup().exists()).toBe(true);
        expect(findBucketName().exists()).toBe(true);
        expect(findBucketName().attributes('placeholder')).toBe(
          ADD_STREAM_EDITOR_I18N.AMAZON_S3_DESTINATION_BUCKET_NAME_PLACEHOLDER,
        );
      });

      it('should render the destination Secret Access Key input', () => {
        expect(findSecretAccessKeyFormGroup().exists()).toBe(true);
        expect(findSecretAccessKey().exists()).toBe(true);
      });

      it('does not render the delete button', () => {
        expect(findDeleteBtn().exists()).toBe(false);
      });

      it('renders the add button text', () => {
        expect(findSubmitStreamBtn().attributes('name')).toBe(
          ADD_STREAM_EDITOR_I18N.ADD_BUTTON_NAME,
        );
        expect(findSubmitStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.ADD_BUTTON_TEXT);
      });

      it('disables the add button at first', () => {
        expect(findSubmitStreamBtn().props('disabled')).toBe(true);
      });
    });

    describe('when add destination event', () => {
      describe('successfully added', () => {
        beforeEach(() => {
          createComponent({
            apolloHandlers: [
              [
                instanceAmazonS3ConfigurationCreate,
                jest.fn().mockResolvedValue(instanceAmazonS3DestinationCreateMutationPopulator()),
              ],
            ],
          });

          findName().setValue(mockInstanceAmazonS3Destinations[0].name);
          findAccessKeyXid().setValue(mockInstanceAmazonS3Destinations[0].accessKeyXid);
          findAwsRegion().setValue(mockInstanceAmazonS3Destinations[0].awsRegion);
          findBucketName().setValue(mockInstanceAmazonS3Destinations[0].bucketName);
          findSecretAccessKey().setValue(mockInstanceAmazonS3Destinations[0].secretAccessKey);
        });
        it('add stream button should be disabled to start', () => {
          expect(findSubmitStreamBtn().props('disabled')).toBe(false);
        });

        it('should emit add event after destination added', async () => {
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(wrapper.emitted('added')).toBeDefined();
        });
        it('should not emit error event after destination added', async () => {
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
        });
      });

      describe('when server returns error', () => {
        const errorMsg = 'Destination hosts limit exceeded';
        beforeEach(() => {
          createComponent({
            apolloHandlers: [
              [
                instanceAmazonS3ConfigurationCreate,
                jest
                  .fn()
                  .mockResolvedValue(
                    instanceAmazonS3DestinationCreateMutationPopulator([errorMsg]),
                  ),
              ],
            ],
          });
          findName().setValue(mockInstanceAmazonS3Destinations[0].name);
          findAccessKeyXid().setValue(mockInstanceAmazonS3Destinations[0].accessKeyXid);
          findAwsRegion().setValue(mockInstanceAmazonS3Destinations[0].awsRegion);
          findBucketName().setValue(mockInstanceAmazonS3Destinations[0].bucketName);
          findSecretAccessKey().setValue(mockInstanceAmazonS3Destinations[0].secretAccessKey);
        });

        it('add stream button should be disabled to start', () => {
          expect(findSubmitStreamBtn().props('disabled')).toBe(false);
        });

        it('should not emit add event after destination added', async () => {
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(wrapper.emitted('added')).toBeUndefined();
        });
        it('should emit error event after destination added', async () => {
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(errorMsg);
          expect(wrapper.emitted('error')).toBeDefined();
        });
      });

      describe('when network errors', () => {
        const sentryError = new Error('Network error');
        let sentryCaptureExceptionSpy;

        beforeEach(async () => {
          sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
          createComponent({
            apolloHandlers: [
              [instanceAmazonS3ConfigurationCreate, jest.fn().mockRejectedValue(sentryError)],
            ],
          });

          findName().setValue(mockInstanceAmazonS3Destinations[0].name);
          findAccessKeyXid().setValue(mockInstanceAmazonS3Destinations[0].accessKeyXid);
          findAwsRegion().setValue(mockInstanceAmazonS3Destinations[0].awsRegion);
          findBucketName().setValue(mockInstanceAmazonS3Destinations[0].bucketName);
          findSecretAccessKey().setValue(mockInstanceAmazonS3Destinations[0].secretAccessKey);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();
        });

        it('shows error alerts', () => {
          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.CREATING_ERROR);
        });

        it('logs to Sentry', () => {
          expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        });

        it('emits correct events', () => {
          expect(wrapper.emitted('error')).toBeDefined();

          expect(wrapper.emitted('added')).toBeUndefined();
        });
      });
    });

    describe('cancel event', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should emit cancel event correctly', () => {
        findCancelStreamBtn().vm.$emit('click');

        expect(wrapper.emitted('cancel')).toBeDefined();
      });
    });

    describe('when editing an existing destination', () => {
      describe('renders', () => {
        beforeEach(() => {
          createComponent({ props: { item: mockInstanceAmazonS3Destinations[0] } });
        });

        it('the name field', () => {
          expect(findName().exists()).toBe(true);
          expect(findName().element.value).toBe(mockInstanceAmazonS3Destinations[0].name);
        });
        it('the access Key id field', () => {
          expect(findAccessKeyXid().exists()).toBe(true);
          expect(findAccessKeyXid().element.value).toBe(
            mockInstanceAmazonS3Destinations[0].accessKeyXid,
          );
        });
        it('the aws Region field', () => {
          expect(findAwsRegion().exists()).toBe(true);
          expect(findAwsRegion().element.value).toBe(mockInstanceAmazonS3Destinations[0].awsRegion);
        });
        it('the bucket Name field', () => {
          expect(findBucketName().exists()).toBe(true);
          expect(findBucketName().element.value).toBe(
            mockInstanceAmazonS3Destinations[0].bucketName,
          );
        });
        it('the Secret Access Key field', () => {
          expect(findSecretAccessKey().exists()).toBe(false);
          expect(findSecretAccessKeyAddButton().exists()).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(false);
        });

        it('the delete button', () => {
          expect(findDeleteBtn().exists()).toBe(true);
        });

        it('renders the save button text', () => {
          expect(findSubmitStreamBtn().attributes('name')).toBe(
            ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_NAME,
          );
          expect(findSubmitStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_TEXT);
        });

        it('disables the save button at first', () => {
          expect(findSubmitStreamBtn().props('disabled')).toBe(true);
        });

        it('displays the secret access key field when adding', async () => {
          await findSecretAccessKeyAddButton().trigger('click');

          expect(findSecretAccessKeyAddButton().props('disabled')).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(true);
          expect(findSecretAccessKey().element.value).toBe('');
        });

        it('removes the secret access key field when cancelled', async () => {
          await findSecretAccessKeyAddButton().trigger('click');
          await findSecretAccessKeyCancelButton().trigger('click');

          expect(findSecretAccessKeyAddButton().props('disabled')).toBe(false);
          expect(findSecretAccessKey().exists()).toBe(false);
          expect(findSecretAccessKeyAddButton().exists()).toBe(true);
          expect(findSecretAccessKeyCancelButton().exists()).toBe(false);
        });
      });

      describe.each`
        name                  | findInputFn
        ${'Destination Name'} | ${findName}
        ${'Access Key Xid'}   | ${findAccessKeyXid}
        ${'AWS Region'}       | ${findAwsRegion}
        ${'Bucket Name'}      | ${findBucketName}
      `('enable the save button when $name is edited', ({ findInputFn }) => {
        beforeEach(() => {
          createComponent({ props: { item: mockInstanceAmazonS3Destinations[0] } });
        });

        it('should have save button disabled', () => {
          expect(findSubmitStreamBtn().props('disabled')).toBe(true);
        });

        it('should have save button enabled', async () => {
          await findInputFn().setValue('test');

          expect(findSubmitStreamBtn().props('disabled')).toBe(false);
        });
      });

      describe('when destination updated', () => {
        beforeEach(async () => {
          createComponent({
            props: { item: mockInstanceAmazonS3Destinations[0] },
            apolloHandlers: [
              [
                instanceAmazonS3ConfigurationUpdate,
                jest.fn().mockResolvedValue(instanceAmazonS3DestinationUpdateMutationPopulator()),
              ],
            ],
          });

          findName().setValue(mockInstanceAmazonS3Destinations[0].name);
          findAccessKeyXid().setValue(mockInstanceAmazonS3Destinations[1].accessKeyXid);
          findAwsRegion().setValue(mockInstanceAmazonS3Destinations[1].awsRegion);
          findBucketName().setValue(mockInstanceAmazonS3Destinations[1].bucketName);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();
        });

        it('should emit updated event', () => {
          expect(wrapper.emitted('updated')).toBeDefined();
        });
        it('not emit error event', () => {
          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
        });
      });

      describe('when destination secret access key updated', () => {
        beforeEach(async () => {
          createComponent({
            props: { item: mockInstanceAmazonS3Destinations[0] },
            apolloHandlers: [
              [
                instanceAmazonS3ConfigurationUpdate,
                jest.fn().mockResolvedValue(instanceAmazonS3DestinationUpdateMutationPopulator()),
              ],
            ],
          });

          await findSecretAccessKeyAddButton().trigger('click');
          findSecretAccessKey().setValue(mockInstanceAmazonS3Destinations[1].secretAccessKey);
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();
        });

        it('should emit updated event', () => {
          expect(wrapper.emitted('updated')).toBeDefined();
        });
        it('should not emit error event', () => {
          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
        });
      });

      describe('when server returns error', () => {
        const errorMsg = 'Destination hosts limit exceeded';

        beforeEach(async () => {
          createComponent({
            props: { item: mockInstanceAmazonS3Destinations[0] },
            apolloHandlers: [
              [
                instanceAmazonS3ConfigurationUpdate,
                jest
                  .fn()
                  .mockResolvedValue(
                    instanceAmazonS3DestinationUpdateMutationPopulator([errorMsg]),
                  ),
              ],
            ],
          });

          findName().setValue(mockInstanceAmazonS3Destinations[0].name);
          findAccessKeyXid().setValue(mockInstanceAmazonS3Destinations[0].accessKeyXid);
          findAwsRegion().setValue(mockInstanceAmazonS3Destinations[0].awsRegion);
          findBucketName().setValue(mockInstanceAmazonS3Destinations[0].bucketName);
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();
        });

        it('should report error', () => {
          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(errorMsg);
          expect(wrapper.emitted('error')).toBeDefined();
        });
        it('should not emit updated destination event', () => {
          expect(wrapper.emitted('updated')).toBeUndefined();
        });
      });

      describe('when network errors', () => {
        const sentryError = new Error('Network error');
        let sentryCaptureExceptionSpy;

        beforeEach(async () => {
          sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
          createComponent({
            props: { item: mockInstanceAmazonS3Destinations[0] },
            apolloHandlers: [
              [instanceAmazonS3ConfigurationUpdate, jest.fn().mockRejectedValue(sentryError)],
            ],
          });

          findName().setValue(mockInstanceAmazonS3Destinations[0].name);
          findAccessKeyXid().setValue(mockInstanceAmazonS3Destinations[0].accessKeyXid);
          findAwsRegion().setValue(mockInstanceAmazonS3Destinations[0].awsRegion);
          findBucketName().setValue(mockInstanceAmazonS3Destinations[0].bucketName);
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();
        });

        it('shows error alerts', () => {
          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
        });

        it('logs to Sentry', () => {
          expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        });

        it('emits correct events', () => {
          expect(wrapper.emitted('error')).toBeDefined();

          expect(wrapper.emitted('added')).toBeUndefined();
        });
      });
    });

    describe('deleting', () => {
      beforeEach(async () => {
        createComponent({ props: { item: mockInstanceAmazonS3Destinations[0] } });
        await findDeleteBtn().trigger('click');
      });

      it('should emit deleting on success operation', async () => {
        await findDeleteModal().vm.$emit('deleting');

        expect(findDeleteBtn().props('loading')).toBe(true);
      });

      it('should emit deleted on success operation', async () => {
        await findDeleteModal().vm.$emit('delete');

        expect(findDeleteBtn().props('loading')).toBe(false);
        expect(wrapper.emitted('deleted')).toEqual([[mockInstanceAmazonS3Destinations[0].id]]);
      });

      it('shows the alert for the error', () => {
        const errorMsg = 'An error occurred';
        findDeleteModal().vm.$emit('error', errorMsg);

        expect(createAlert).toHaveBeenCalledWith({
          message: AUDIT_STREAMS_NETWORK_ERRORS.DELETING_ERROR,
          captureError: true,
          error: errorMsg,
        });
      });
    });

    it('passes actual newlines when these are used in the secret access key input', async () => {
      const mutationMock = jest
        .fn()
        .mockResolvedValue(instanceAmazonS3DestinationCreateMutationPopulator());
      createComponent({
        apolloHandlers: [[instanceAmazonS3ConfigurationCreate, mutationMock]],
      });

      await findSecretAccessKey().setValue('\\ntest\\n');
      await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });

      expect(mutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          secretAccessKey: '\ntest\n',
        }),
      );
    });
  });
});
