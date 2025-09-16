import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlFormCheckbox, GlForm, GlTableLite } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { sprintf } from '~/locale';
import { createAlert } from '~/alert';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import { removeAuditEventsStreamingDestinationFromCache } from 'ee/audit_events/graphql/cache_update_consolidated_api';
import { removeLegacyAuditEventsStreamingDestination } from 'ee/audit_events/graphql/cache_update';
import getNamespaceFiltersQuery from 'ee/audit_events/graphql/queries/get_namespace_filters.query.graphql';
import externalAuditEventDestinationCreate from 'ee/audit_events/graphql/mutations/create_external_destination.mutation.graphql';
import externalAuditEventDestinationUpdate from 'ee/audit_events/graphql/mutations/update_external_destination.mutation.graphql';
import externalAuditEventDestinationHeaderCreate from 'ee/audit_events/graphql/mutations/create_external_destination_header.mutation.graphql';
import externalAuditEventDestinationHeaderUpdate from 'ee/audit_events/graphql/mutations/update_external_destination_header.mutation.graphql';
import externalAuditEventDestinationHeaderDelete from 'ee/audit_events/graphql/mutations/delete_external_destination_header.mutation.graphql';
import deleteExternalDestination from 'ee/audit_events/graphql/mutations/delete_external_destination.mutation.graphql';
import deleteExternalDestinationFilters from 'ee/audit_events/graphql/mutations/delete_external_destination_filters.mutation.graphql';
import addExternalDestinationFilters from 'ee/audit_events/graphql/mutations/add_external_destination_filters.mutation.graphql';
import instanceExternalAuditEventDestinationCreate from 'ee/audit_events/graphql/mutations/create_instance_external_destination.mutation.graphql';
import instanceExternalAuditEventDestinationUpdate from 'ee/audit_events/graphql/mutations/update_instance_external_destination.mutation.graphql';
import deleteInstanceExternalDestination from 'ee/audit_events/graphql/mutations/delete_instance_external_destination.mutation.graphql';
import externalInstanceAuditEventDestinationHeaderCreate from 'ee/audit_events/graphql/mutations/create_instance_external_destination_header.mutation.graphql';
import externalInstanceAuditEventDestinationHeaderUpdate from 'ee/audit_events/graphql/mutations/update_instance_external_destination_header.mutation.graphql';
import externalInstanceAuditEventDestinationHeaderDelete from 'ee/audit_events/graphql/mutations/delete_instance_external_destination_header.mutation.graphql';
import deleteInstanceExternalDestinationFilters from 'ee/audit_events/graphql/mutations/delete_instance_external_destination_filters.mutation.graphql';
import addInstanceExternalDestinationFilters from 'ee/audit_events/graphql/mutations/add_instance_external_destination_filters.mutation.graphql';
import addExternalDestinationNamespaceFilters from 'ee/audit_events/graphql/mutations/add_external_destination_namespace_filters.mutation.graphql';
import deleteExternalDestinationNamespaceFilters from 'ee/audit_events/graphql/mutations/delete_external_destination_namespace_filters.mutation.graphql';
import StreamHttpDestinationEditor from 'ee/audit_events/components/stream/stream_http_destination_editor.vue';
import StreamEventTypeFilters from 'ee/audit_events/components/stream/stream_event_type_filters.vue';
import StreamNamespaceFilters from 'ee/audit_events/components/stream//stream_namespace_filters.vue';
import StreamDeleteModal from 'ee/audit_events/components/stream/stream_delete_modal.vue';
import { AUDIT_STREAMS_NETWORK_ERRORS, ADD_STREAM_EDITOR_I18N } from 'ee/audit_events/constants';
import {
  destinationCreateMutationPopulator,
  destinationDeleteMutationPopulator,
  destinationUpdateMutationPopulator,
  destinationHeaderCreateMutationPopulator,
  destinationHeaderUpdateMutationPopulator,
  destinationHeaderDeleteMutationPopulator,
  groupPath,
  mockExternalDestinations,
  mockInstanceExternalDestinations,
  mockExternalDestinationHeader,
  destinationFilterRemoveMutationPopulator,
  destinationFilterUpdateMutationPopulator,
  mockAuditEventDefinitions,
  mockRemoveFilterSelect,
  mockRemoveFilterRemaining,
  mockAddFilterSelect,
  mockAddFilterRemaining,
  instanceGroupPath,
  mockInstanceExternalDestinationHeader,
  destinationInstanceCreateMutationPopulator,
  destinationInstanceDeleteMutationPopulator,
  destinationInstanceHeaderCreateMutationPopulator,
  destinationInstanceHeaderUpdateMutationPopulator,
  destinationInstanceHeaderDeleteMutationPopulator,
  destinationInstanceFilterRemoveMutationPopulator,
  destinationInstanceFilterUpdateMutationPopulator,
  destinationInstanceUpdateMutationPopulator,
  mockNamespaceFilter,
  destinationNamespaceFilterRemoveMutationPopulator,
  destinationNamespaceFilterAddMutationPopulator,
  mockAddNamespaceFilters,
  mockRemoveNamespaceFilters,
  getMockNamespaceFilters,
} from '../../mock_data';
import { mockHttpTypeDestination } from '../../mock_data/consolidated_api';

jest.mock('~/alert');
jest.mock('ee/audit_events/graphql/cache_update');
jest.mock('ee/audit_events/graphql/cache_update_consolidated_api');

Vue.use(VueApollo);

describe('StreamHttpDestinationEditor', () => {
  let wrapper;
  let groupPathProvide = groupPath;

  const maxHeaders = 3;
  const defaultDeleteSpy = jest.fn().mockResolvedValue(destinationDeleteMutationPopulator());

  const createComponent = ({
    mountFn = mountExtended,
    props = {},
    provide = {},
    apolloHandlers = [
      [
        externalAuditEventDestinationCreate,
        jest.fn().mockResolvedValue(destinationCreateMutationPopulator()),
      ],
    ],
  } = {}) => {
    const STATIC_HANDLERS = [
      [getNamespaceFiltersQuery, jest.fn().mockResolvedValue(getMockNamespaceFilters())],
    ];
    const mockApollo = createMockApollo([...apolloHandlers, ...STATIC_HANDLERS]);
    wrapper = mountFn(StreamHttpDestinationEditor, {
      attachTo: document.body,
      provide: {
        groupPath: groupPathProvide,
        maxHeaders,
        auditEventDefinitions: mockAuditEventDefinitions,
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
  const findHeadersTable = () => wrapper.findComponent(GlTableLite);
  const findNoHeaderCreatedText = () => wrapper.findByTestId('no-header-created');
  const findMaximumHeadersText = () => wrapper.findByTestId('maximum-headers');
  const findAddHeaderBtn = () => wrapper.findByTestId('add-header-row-button');
  const findSubmitStreamBtn = () => wrapper.findByTestId('stream-destination-submit-button');
  const findCancelStreamBtn = () => wrapper.findByTestId('stream-destination-cancel-button');
  const findDeleteBtn = () => wrapper.findByTestId('stream-destination-delete-button');
  const findDeleteModal = () => wrapper.findComponent(StreamDeleteModal);

  const findDestinationUrlFormGroup = () => wrapper.findByTestId('destination-url-form-group');
  const findDestinationUrl = () => wrapper.findByTestId('destination-url');

  const findDestinationNameFormGroup = () => wrapper.findByTestId('destination-name-form-group');
  const findDestinationName = () => wrapper.findByTestId('destination-name');

  const findVerificationTokenFormGroup = () =>
    wrapper.findByTestId('verification-token-form-group');
  const findVerificationToken = () => wrapper.findByTestId('verification-token');
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);

  const findFilteringHeader = () => wrapper.findByTestId('filtering-header');
  const findEventTypeFilteringHeader = () => wrapper.findByTestId('event-type-filtering-header');
  const findFilters = () => wrapper.findComponent(StreamEventTypeFilters);
  const findNamespaceFilters = () => wrapper.findComponent(StreamNamespaceFilters);
  const findNamespaceFilteringHeader = () =>
    wrapper.findByTestId('event-namespace-filtering-header');
  const findHeadersRows = () => findHeadersTable().find('tbody').findAll('tr');
  const findHeadersHeaderCell = (tdIdx) =>
    findHeadersTable().find('thead tr').findAll('th').at(tdIdx);
  const findHeaderCheckbox = (trIdx) => findHeadersRows().at(trIdx).findComponent(GlFormCheckbox);
  const findHeaderDeleteBtn = (trIdx) => findHeadersRows().at(trIdx).findComponent(GlButton);
  const findHeaderNameInput = (trIdx) =>
    extendedWrapper(findHeadersRows().at(trIdx)).findByTestId('header-name-input');
  const findHeaderValueInput = (trIdx) =>
    extendedWrapper(findHeadersRows().at(trIdx)).findByTestId('header-value-input');
  const findHeaderActiveInput = (trIdx) =>
    extendedWrapper(findHeadersRows().at(trIdx)).findByTestId('header-active-input');

  const setHeaderNameInput = (trIdx, name) => findHeaderNameInput(trIdx).setValue(name);
  const setHeaderValueInput = (trIdx, value) => findHeaderValueInput(trIdx).setValue(value);

  const setHeadersRowData = async (trIdx, { name, value }) => {
    await setHeaderNameInput(trIdx, name);
    await setHeaderValueInput(trIdx, value);
  };

  const submitForm = async () => {
    findDestinationName().setValue('Name');
    findDestinationUrl().setValue('https://example.test');
    findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
    await waitForPromises();
  };

  const submitFormWithHeaders = async () => {
    findDestinationName().setValue('Name');
    findDestinationUrl().setValue('https://example.test');
    await findAddHeaderBtn().trigger('click');
    await setHeadersRowData(0, { name: 'row header', value: 'row value' });
    await findAddHeaderBtn().trigger('click');
    await setHeadersRowData(1, { name: 'row header 1', value: 'row value 1' });
    findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
    await waitForPromises();
  };

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('when useConsolidatedAuditEventStreamDestApi is enabled', () => {
    const item = mockHttpTypeDestination[0];

    beforeEach(() => {
      createComponent({
        props: { item },
        provide: {
          glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
        },
      });
    });

    it('renders the destination correctly', () => {
      expect(findWarningMessage().exists()).toBe(false);
      expect(findDestinationName().element.value).toBe('HTTP Destination 1');
      expect(findDestinationUrl().element.value).toBe('http://destination1.local');
      expect(findDestinationUrl().attributes('disabled')).toBeDefined();
      expect(findVerificationToken().props('value')).toBe('mockSecretToken');
      expect(findClipboardButton().props('text')).toBe('mockSecretToken');
      expect(findHeaderNameInput(0).element.value).toBe('key1');
      expect(findHeaderValueInput(0).element.value).toBe('test');
      expect(findHeaderActiveInput(0).element.value).toBe('true');
      expect(findFilters().props()).toStrictEqual({
        value: ['user_created'],
      });
      expect(findNamespaceFilters().props()).toMatchObject({
        value: mockNamespaceFilter('myGroup/project1'),
      });
      expect(findDeleteModal().props('item')).toBe(item);
    });

    describe('when there is an error on adding a destination header', () => {
      it('should call removeAuditEventsStreamingDestinationFromCache', async () => {
        createComponent({
          apolloHandlers: [
            [
              externalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationCreateMutationPopulator()),
            ],
            [
              externalAuditEventDestinationHeaderCreate,
              jest.fn().mockResolvedValue(destinationHeaderCreateMutationPopulator(['error'])),
            ],
            [deleteExternalDestination, defaultDeleteSpy],
          ],
          provide: {
            glFeatures: { useConsolidatedAuditEventStreamDestApi: true },
          },
        });

        await submitFormWithHeaders();

        expect(removeAuditEventsStreamingDestinationFromCache).toHaveBeenCalled();
      });
    });
  });

  describe('Group StreamHttpDestinationEditor', () => {
    describe('when initialized', () => {
      describe('destinations URL', () => {
        beforeEach(() => {
          createComponent();
        });

        it('should render the destinations warning', () => {
          expect(findWarningMessage().props('title')).toBe(ADD_STREAM_EDITOR_I18N.WARNING_TITLE);
          expect(findWarningMessage().text()).toContain(ADD_STREAM_EDITOR_I18N.WARNING_CONTENT);
        });

        it('should render the destination URL input', () => {
          expect(findDestinationUrlFormGroup().exists()).toBe(true);
          expect(findDestinationUrl().props('disabled')).toBe(false);
          expect(findDestinationUrl().attributes('placeholder')).toBe(
            ADD_STREAM_EDITOR_I18N.DESTINATION_URL_PLACEHOLDER,
          );
        });

        it('should render the destination name input', () => {
          expect(findDestinationNameFormGroup().exists()).toBe(true);
        });

        it('should render the event type filter', () => {
          expect(findFilters().exists()).toBe(true);
        });

        it('should render the namespace filter', () => {
          expect(findNamespaceFilters().exists()).toBe(true);
        });
      });

      it('does not render verification token', () => {
        createComponent();

        expect(findVerificationTokenFormGroup().exists()).toBe(false);
      });

      describe('HTTP headers', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended });
        });

        it('should render no headers created message', () => {
          expect(findNoHeaderCreatedText().text()).toBe(
            ADD_STREAM_EDITOR_I18N.NO_HEADER_CREATED_TEXT,
          );
        });

        it('should render empty table row when adding new header', async () => {
          await findAddHeaderBtn().trigger('click');

          expect(findHeadersRows()).toHaveLength(1);
          expect(findNoHeaderCreatedText().exists()).toBe(false);

          expect(findHeadersHeaderCell(0).text()).toBe('');
          expect(findHeadersHeaderCell(1).text()).toBe('');
          expect(findHeadersHeaderCell(2).text()).toBe('');
          expect(findHeadersHeaderCell(3).text()).toBe('');

          expect(findHeaderNameInput(0).attributes('placeholder')).toBe(
            ADD_STREAM_EDITOR_I18N.HEADER_INPUT_PLACEHOLDER,
          );
          expect(findHeaderValueInput(0).attributes('placeholder')).toBe(
            ADD_STREAM_EDITOR_I18N.VALUE_INPUT_PLACEHOLDER,
          );
          expect(findHeaderCheckbox(0).find('input').attributes('value')).toBe('true');
          expect(findHeaderDeleteBtn(0).exists()).toBe(true);
        });
      });

      it('does not render delete button', () => {
        createComponent();

        expect(findDeleteBtn().exists()).toBe(false);
      });
    });

    describe('add destination event without headers', () => {
      it('should emit add event after destination added', async () => {
        createComponent();

        await submitForm();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('added')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          apolloHandlers: [
            [
              externalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationCreateMutationPopulator([errorMsg])),
            ],
          ],
        });

        await submitForm();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.CREATING_ERROR);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });

      it('should not emit add destination event and reports error when network error occurs', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          apolloHandlers: [
            [externalAuditEventDestinationCreate, jest.fn().mockRejectedValue(sentryError)],
          ],
        });

        await submitForm();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.CREATING_ERROR);
        expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });
    });

    describe('add destination event with headers', () => {
      it('should emit add event after destination and headers are added', async () => {
        createComponent({
          mountFn: mountExtended,
          apolloHandlers: [
            [
              externalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationCreateMutationPopulator()),
            ],
            [
              externalAuditEventDestinationHeaderCreate,
              jest.fn().mockResolvedValue(destinationHeaderCreateMutationPopulator()),
            ],
          ],
        });

        await submitFormWithHeaders();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('added')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error while adding headers', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          mountFn: mountExtended,
          apolloHandlers: [
            [
              externalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationCreateMutationPopulator()),
            ],
            [
              externalAuditEventDestinationHeaderCreate,
              jest
                .fn()
                .mockResolvedValueOnce(destinationHeaderCreateMutationPopulator())
                .mockResolvedValue(destinationHeaderCreateMutationPopulator([errorMsg])),
            ],
            [deleteExternalDestination, defaultDeleteSpy],
          ],
        });

        await submitFormWithHeaders();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(errorMsg);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });

      it('should call removeLegacyAuditEventsStreamingDestination when server returns error while adding headers', async () => {
        createComponent({
          apolloHandlers: [
            [
              externalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationCreateMutationPopulator()),
            ],
            [
              externalAuditEventDestinationHeaderCreate,
              jest.fn().mockResolvedValue(destinationHeaderCreateMutationPopulator(['error'])),
            ],
            [deleteExternalDestination, defaultDeleteSpy],
          ],
        });

        await submitFormWithHeaders();

        expect(removeLegacyAuditEventsStreamingDestination).toHaveBeenCalled();
      });

      it('should not emit add destination event and reports error when network error occurs while adding headers', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          mountFn: mountExtended,
          apolloHandlers: [
            [
              externalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationCreateMutationPopulator()),
            ],
            [
              externalAuditEventDestinationHeaderCreate,
              jest
                .fn()
                .mockResolvedValueOnce(destinationHeaderCreateMutationPopulator())
                .mockRejectedValue(sentryError),
            ],
            [deleteExternalDestination, defaultDeleteSpy],
          ],
        });

        await submitFormWithHeaders();

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

    describe('HTTP headers table', () => {
      beforeEach(() => {
        createComponent({ mountFn: mountExtended });
      });

      it('should add a new blank row if the add row button is clicked', async () => {
        expect(findHeadersRows()).toHaveLength(0);

        await findAddHeaderBtn().trigger('click');

        expect(findHeadersRows()).toHaveLength(1);
      });

      it.each`
        name     | value    | disabled
        ${''}    | ${''}    | ${true}
        ${'abc'} | ${''}    | ${true}
        ${''}    | ${'abc'} | ${true}
        ${'abc'} | ${'abc'} | ${false}
      `(
        'should enable the add button only when both the name and value are filled',
        async ({ name, value, disabled }) => {
          findDestinationName().setValue('Name');
          findDestinationUrl().setValue('https://example.test');
          await findAddHeaderBtn().trigger('click');
          await setHeadersRowData(0, { name, value });

          expect(findSubmitStreamBtn().props('disabled')).toBe(disabled);
        },
      );

      it('disables add button when there are headers with the same name', async () => {
        findDestinationName().setValue('Name');
        findDestinationUrl().setValue('https://example.test');
        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(0, { name: 'a', value: 'b' });

        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(1, { name: 'a', value: 'c' });
        expect(findSubmitStreamBtn().props('disabled')).toBe(true);
      });

      it('should delete a row when the delete button is clicked', async () => {
        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(0, { name: 'row header', value: 'row value' });
        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(1, { name: 'row header 2', value: 'row value 2' });
        await findAddHeaderBtn().trigger('click');

        expect(findHeadersRows()).toHaveLength(3);

        await findHeaderDeleteBtn(1).trigger('click');

        expect(findHeadersRows()).toHaveLength(2);
        expect(findHeaderNameInput(0).element.value).toBe('row header');
        expect(findHeaderValueInput(0).element.value).toBe('row value');
        expect(findHeaderNameInput(1).element.value).toBe('');
        expect(findHeaderValueInput(1).element.value).toBe('');
      });

      it('enables add button when first header with the same name is deleted', async () => {
        findDestinationName().setValue('Name');
        findDestinationUrl().setValue('https://example.test');

        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(0, { name: 'a', value: 'b' });

        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(1, { name: 'a', value: 'c' });

        await findHeaderDeleteBtn(0).trigger('click');

        expect(findSubmitStreamBtn().props('disabled')).toBe(false);
      });

      it('keeps add button disabled when invalid header with the same name is deleted', async () => {
        findDestinationName().setValue('Name');
        findDestinationUrl().setValue('https://example.test');

        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(0, { name: 'a', value: 'b' });

        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(1, { name: 'a', value: 'c' });

        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(1, { name: 'a', value: 'c' });

        await findHeaderDeleteBtn(1).trigger('click');

        expect(findSubmitStreamBtn().props('disabled')).toBe(true);
      });

      it('should show the maximum number of rows message only when the maximum is reached', async () => {
        await findAddHeaderBtn().trigger('click');
        await findAddHeaderBtn().trigger('click');

        expect(findMaximumHeadersText().exists()).toBe(false);

        await findAddHeaderBtn().trigger('click');

        expect(findHeadersRows()).toHaveLength(maxHeaders);
        expect(findAddHeaderBtn().exists()).toBe(false);
        expect(findMaximumHeadersText().text()).toMatchInterpolatedText(
          sprintf(ADD_STREAM_EDITOR_I18N.MAXIMUM_HEADERS_TEXT, { number: maxHeaders }),
        );
      });
    });

    describe('when editing an existing destination', () => {
      const item = {
        ...mockExternalDestinations[0],
        headers: { nodes: [mockExternalDestinationHeader(), mockExternalDestinationHeader()] },
      };

      describe('renders', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended, props: { item } });
        });

        it('renders the delete modal', () => {
          expect(findDeleteModal().props('item')).toBe(item);
        });

        it('should not render the destinations warning', () => {
          expect(findWarningMessage().exists()).toBe(false);
        });

        it('disables the destination URL field', () => {
          expect(findDestinationUrl().element.value).toBe(
            mockExternalDestinations[0].destinationUrl,
          );
          expect(findDestinationUrl().attributes('disabled')).toBeDefined();
        });

        it('renders verification token and clipboard button', () => {
          expect(findVerificationTokenFormGroup().classes('gl-max-w-34')).toBe(true);
          expect(findVerificationToken().attributes('readonly')).toBeDefined();
          expect(findVerificationToken().props('value')).toBe(item.verificationToken);
          expect(findClipboardButton().props('text')).toBe(item.verificationToken);
          expect(findClipboardButton().props('title')).toBe('Copy to clipboard');
        });

        it('changes the save button text', () => {
          expect(findSubmitStreamBtn().attributes('name')).toBe(
            ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_NAME,
          );
          expect(findSubmitStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_TEXT);
        });

        it('disables the save button text at first', () => {
          expect(findSubmitStreamBtn().props('disabled')).toBe(true);
        });

        it('renders the delete button', () => {
          expect(findDeleteBtn().attributes('name')).toBe(
            ADD_STREAM_EDITOR_I18N.DELETE_BUTTON_TEXT,
          );
          expect(findDeleteBtn().classes('gl-ml-auto')).toBe(true);
          expect(findDeleteBtn().props('variant')).toBe('danger');
          expect(findDeleteBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.DELETE_BUTTON_TEXT);
        });
      });

      describe('update destinations headers', () => {
        const updatedHeader = { ...item.headers.nodes[0], newValue: 'CHANGED_VALUE' };
        const deletedHeader = item.headers.nodes[1];
        const addedHeader = mockExternalDestinationHeader();

        const setupUpdatedHeaders = async (updated, added) => {
          findDestinationName().setValue('Name');
          findDestinationUrl().setValue('https://example.test');
          await setHeadersRowData(0, { name: updated.key, value: updated.newValue });
          await findHeaderDeleteBtn(1).trigger('click');
          await findAddHeaderBtn().trigger('click');
          await setHeadersRowData(1, { name: added.key, value: added.value });
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });

          return waitForPromises();
        };

        it('emits the updated event when the headers are added, updated, and deleted', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());
          const headerCreateSpy = jest
            .fn()
            .mockResolvedValue(destinationHeaderCreateMutationPopulator());
          const headerUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationHeaderUpdateMutationPopulator());
          const headerDeleteSpy = jest
            .fn()
            .mockResolvedValue(destinationHeaderDeleteMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [externalAuditEventDestinationHeaderCreate, headerCreateSpy],
              [externalAuditEventDestinationHeaderUpdate, headerUpdateSpy],
              [externalAuditEventDestinationHeaderDelete, headerDeleteSpy],
            ],
          });

          await setupUpdatedHeaders(updatedHeader, addedHeader);

          expect(destinationUpdateSpy).toHaveBeenCalledTimes(1);

          expect(headerDeleteSpy).toHaveBeenCalledTimes(1);
          expect(headerDeleteSpy).toHaveBeenCalledWith({
            headerId: deletedHeader.id,
          });
          expect(headerUpdateSpy).toHaveBeenCalledTimes(1);
          expect(headerUpdateSpy).toHaveBeenCalledWith({
            headerId: updatedHeader.id,
            key: updatedHeader.key,
            value: updatedHeader.newValue,
            active: false,
          });
          expect(headerCreateSpy).toHaveBeenCalledTimes(1);
          expect(headerCreateSpy).toHaveBeenCalledWith({
            destinationId: item.id,
            key: addedHeader.key,
            value: addedHeader.value,
            active: true,
          });
          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('handles adding & removal header with the same name', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());
          const headerCreateSpy = jest
            .fn()
            .mockResolvedValue(destinationHeaderCreateMutationPopulator());
          const headerDeleteSpy = jest
            .fn()
            .mockResolvedValue(destinationHeaderDeleteMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [externalAuditEventDestinationHeaderCreate, headerCreateSpy],
              [externalAuditEventDestinationHeaderDelete, headerDeleteSpy],
            ],
          });
          await waitForPromises();

          findDestinationName().setValue('Name');
          findDestinationUrl().setValue('https://example.test');
          await findHeaderDeleteBtn(1).trigger('click');
          await findAddHeaderBtn().trigger('click');
          await setHeadersRowData(1, { name: item.headers.nodes[0].key, value: 'NEW' });
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });

          await waitForPromises();

          expect(headerDeleteSpy).toHaveBeenCalledTimes(1);
          expect(headerDeleteSpy).toHaveBeenCalledWith({
            headerId: deletedHeader.id,
          });
          expect(headerCreateSpy).toHaveBeenCalledTimes(1);
          expect(headerCreateSpy).toHaveBeenCalledWith({
            destinationId: item.id,
            key: item.headers.nodes[0].key,
            value: 'NEW',
            active: true,
          });
          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('should not emit updated event and reports error when server returns error while saving', async () => {
          const errorMsg = 'Destination hosts limit exceeded';

          createComponent({
            mountFn: mountExtended,
            props: { item },
            apolloHandlers: [
              [
                externalAuditEventDestinationUpdate,
                jest.fn().mockResolvedValue(destinationUpdateMutationPopulator()),
              ],
              [
                externalAuditEventDestinationHeaderCreate,
                jest.fn().mockResolvedValue(destinationHeaderCreateMutationPopulator([errorMsg])),
              ],
              [
                externalAuditEventDestinationHeaderUpdate,
                jest.fn().mockResolvedValue(destinationHeaderUpdateMutationPopulator()),
              ],
              [
                externalAuditEventDestinationHeaderDelete,
                jest.fn().mockResolvedValue(destinationHeaderDeleteMutationPopulator()),
              ],
            ],
          });

          await setupUpdatedHeaders(updatedHeader, addedHeader);

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(errorMsg);
          expect(wrapper.emitted('error')).toBeDefined();
          expect(wrapper.emitted('updated')).toBeUndefined();
        });

        it('should not emit updated event and reports error when network error occurs while saving', async () => {
          const sentryError = new Error('Network error');
          const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');

          createComponent({
            mountFn: mountExtended,
            props: { item },
            apolloHandlers: [
              [
                externalAuditEventDestinationUpdate,
                jest.fn().mockResolvedValue(destinationUpdateMutationPopulator()),
              ],
              [externalAuditEventDestinationHeaderUpdate, jest.fn().mockRejectedValue(sentryError)],
              [
                externalAuditEventDestinationHeaderDelete,
                jest.fn().mockResolvedValue(destinationHeaderDeleteMutationPopulator()),
              ],
            ],
          });

          await setupUpdatedHeaders(updatedHeader, addedHeader);

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
          expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
          expect(wrapper.emitted('error')).toBeDefined();
          expect(wrapper.emitted('updated')).toBeUndefined();
        });
      });

      describe('deleting', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended, props: { item } });
        });

        it('should emit deleted on success operation', async () => {
          const deleteButton = findDeleteBtn();
          await deleteButton.trigger('click');
          await findDeleteModal().vm.$emit('deleting');

          expect(deleteButton.props('loading')).toBe(true);

          await findDeleteModal().vm.$emit('delete');

          expect(deleteButton.props('loading')).toBe(false);
          expect(wrapper.emitted('deleted')).toEqual([[item.id]]);
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
    });

    describe('destination event type filters', () => {
      describe('renders', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended, props: { item: mockExternalDestinations[1] } });
        });

        it('displays the correct text', () => {
          expect(findFilteringHeader().text()).toBe(ADD_STREAM_EDITOR_I18N.HEADER_FILTERING);
          expect(findEventTypeFilteringHeader().text()).toBe(
            ADD_STREAM_EDITOR_I18N.FILTER_BY_AUDIT_EVENT_TYPE,
          );
        });

        it('passes selected audit event types to StreamEventTypeFilters', () => {
          expect(findFilters().props()).toStrictEqual({
            value: mockExternalDestinations[1].eventTypeFilters,
          });
        });
      });

      describe('on change filters', () => {
        it('removes the deselected filters from a destination', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());

          const filterRemoveSpy = jest
            .fn()
            .mockResolvedValue(destinationFilterRemoveMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item: mockExternalDestinations[1] },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [deleteExternalDestinationFilters, filterRemoveSpy],
            ],
          });

          await findFilters().vm.$emit('input', mockRemoveFilterSelect);

          expect(findSubmitStreamBtn().props('disabled')).toBe(false);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(filterRemoveSpy).toHaveBeenCalledWith({
            destinationId: mockExternalDestinations[1].id,
            eventTypeFilters: mockRemoveFilterRemaining,
          });

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('adds the selected filters for a destination', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());

          const filterAddSpy = jest
            .fn()
            .mockResolvedValue(destinationFilterUpdateMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item: mockExternalDestinations[1] },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [addExternalDestinationFilters, filterAddSpy],
            ],
          });

          await findFilters().vm.$emit('input', mockAddFilterSelect);

          expect(findSubmitStreamBtn().props('disabled')).toBe(false);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(filterAddSpy).toHaveBeenCalledWith({
            destinationId: mockExternalDestinations[1].id,
            eventTypeFilters: mockAddFilterRemaining,
          });

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('should not emit updated event and reports error when network error occurs while saving', async () => {
          const sentryError = new Error('Network error');
          const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());
          const filterRemoveSpy = jest.fn().mockRejectedValue(sentryError);

          createComponent({
            mountFn: mountExtended,
            props: { item: mockExternalDestinations[1] },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [deleteExternalDestinationFilters, filterRemoveSpy],
            ],
          });

          findFilters().vm.$emit('input', mockRemoveFilterSelect);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
          expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
          expect(wrapper.emitted('error')).toBeDefined();
          expect(wrapper.emitted('updated')).toBeUndefined();
        });
      });
    });

    describe('destination namespace filters', () => {
      describe('renders', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended, props: { item: mockExternalDestinations[1] } });
        });

        it('displays the correct text', () => {
          expect(findNamespaceFilteringHeader().text()).toBe(
            ADD_STREAM_EDITOR_I18N.FILTER_BY_NAMESPACE,
          );
        });

        it('passes selected namespace to StreamEventTypeFilters', () => {
          expect(findNamespaceFilters().props()).toMatchObject({
            value: mockNamespaceFilter(
              mockExternalDestinations[1].namespaceFilter.namespace.fullPath,
            ),
          });
        });
      });

      describe('on change filters', () => {
        it('removes the current filter from a destination', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());

          const namespaceFilterRemoveSpy = jest
            .fn()
            .mockResolvedValue(destinationNamespaceFilterRemoveMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item: mockExternalDestinations[1] },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [deleteExternalDestinationNamespaceFilters, namespaceFilterRemoveSpy],
            ],
          });

          await findNamespaceFilters().vm.$emit('input', mockRemoveNamespaceFilters);

          expect(findSubmitStreamBtn().props('disabled')).toBe(false);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(namespaceFilterRemoveSpy).toHaveBeenCalledWith({
            namespaceFilterId: mockExternalDestinations[1].namespaceFilter.id,
          });

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('adds the selected filter for a destination', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());

          const namespaceFilterAddSpy = jest
            .fn()
            .mockResolvedValue(destinationNamespaceFilterAddMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item: mockExternalDestinations[0] },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [addExternalDestinationNamespaceFilters, namespaceFilterAddSpy],
            ],
          });

          await findNamespaceFilters().vm.$emit('input', mockAddNamespaceFilters);

          expect(findSubmitStreamBtn().props('disabled')).toBe(false);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(namespaceFilterAddSpy).toHaveBeenCalledWith({
            destinationId: mockExternalDestinations[0].id,
            projectPath: mockAddNamespaceFilters.namespace,
          });

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('should not emit updated event and reports error when network error occurs while saving', async () => {
          const sentryError = new Error('Network error');
          const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationUpdateMutationPopulator());
          const filterRemoveSpy = jest.fn().mockRejectedValue(sentryError);

          createComponent({
            mountFn: mountExtended,
            props: { item: mockExternalDestinations[1] },
            apolloHandlers: [
              [externalAuditEventDestinationUpdate, destinationUpdateSpy],
              [deleteExternalDestinationNamespaceFilters, filterRemoveSpy],
            ],
          });

          findNamespaceFilters().vm.$emit('input', mockRemoveNamespaceFilters);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
          expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
          expect(wrapper.emitted('error')).toBeDefined();
          expect(wrapper.emitted('updated')).toBeUndefined();
        });
      });
    });
  });

  describe('Instance StreamHttpDestinationEditor', () => {
    beforeEach(() => {
      groupPathProvide = instanceGroupPath;
    });

    describe('when initialized', () => {
      describe('destinations URL', () => {
        beforeEach(() => {
          createComponent();
        });

        it('should render the destinations warning', () => {
          expect(findWarningMessage().props('title')).toBe(ADD_STREAM_EDITOR_I18N.WARNING_TITLE);
          expect(findWarningMessage().text()).toContain(ADD_STREAM_EDITOR_I18N.WARNING_CONTENT);
        });

        it('should render the destination URL input', () => {
          expect(findDestinationUrlFormGroup().exists()).toBe(true);
          expect(findDestinationUrl().props('disabled')).toBe(false);
          expect(findDestinationUrl().attributes('placeholder')).toBe(
            ADD_STREAM_EDITOR_I18N.DESTINATION_URL_PLACEHOLDER,
          );
        });

        it('does not render verification token', () => {
          expect(findVerificationTokenFormGroup().exists()).toBe(false);
        });

        it('does not render delete button', () => {
          createComponent();

          expect(findDeleteBtn().exists()).toBe(false);
        });
      });

      describe('HTTP headers', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended });
        });

        it('should render no headers created message', () => {
          expect(findNoHeaderCreatedText().text()).toBe(
            ADD_STREAM_EDITOR_I18N.NO_HEADER_CREATED_TEXT,
          );
        });

        it('should render empty table row when adding new header', async () => {
          await findAddHeaderBtn().trigger('click');

          expect(findHeadersRows()).toHaveLength(1);
          expect(findNoHeaderCreatedText().exists()).toBe(false);

          expect(findHeadersHeaderCell(0).text()).toBe('');
          expect(findHeadersHeaderCell(1).text()).toBe('');
          expect(findHeadersHeaderCell(2).text()).toBe('');
          expect(findHeadersHeaderCell(3).text()).toBe('');

          expect(findHeaderNameInput(0).attributes('placeholder')).toBe(
            ADD_STREAM_EDITOR_I18N.HEADER_INPUT_PLACEHOLDER,
          );
          expect(findHeaderValueInput(0).attributes('placeholder')).toBe(
            ADD_STREAM_EDITOR_I18N.VALUE_INPUT_PLACEHOLDER,
          );
          expect(findHeaderCheckbox(0).find('input').attributes('value')).toBe('true');
          expect(findHeaderDeleteBtn(0).exists()).toBe(true);
        });
      });
    });

    describe('add destination event', () => {
      it('should emit add event after destination added', async () => {
        createComponent({
          apolloHandlers: [
            [
              instanceExternalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationInstanceCreateMutationPopulator()),
            ],
          ],
        });

        await submitForm();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('added')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          apolloHandlers: [
            [
              instanceExternalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationInstanceCreateMutationPopulator([errorMsg])),
            ],
          ],
        });

        await submitForm();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(errorMsg);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });

      it('should not emit add destination event and reports error when network error occurs', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          apolloHandlers: [
            [instanceExternalAuditEventDestinationCreate, jest.fn().mockRejectedValue(sentryError)],
          ],
        });

        await submitForm();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.CREATING_ERROR);
        expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });
    });

    describe('add destination event with headers', () => {
      it('should emit add event after destination and headers are added', async () => {
        createComponent({
          mountFn: mountExtended,
          apolloHandlers: [
            [
              instanceExternalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationInstanceCreateMutationPopulator()),
            ],
            [
              externalInstanceAuditEventDestinationHeaderCreate,
              jest.fn().mockResolvedValue(destinationInstanceHeaderCreateMutationPopulator()),
            ],
          ],
        });

        await submitFormWithHeaders();

        expect(findAlertErrors()).toHaveLength(0);
        expect(wrapper.emitted('error')).toBeUndefined();
        expect(wrapper.emitted('added')).toBeDefined();
      });

      it('should not emit add destination event and reports error when server returns error while adding headers', async () => {
        const errorMsg = 'Destination hosts limit exceeded';
        createComponent({
          mountFn: mountExtended,
          apolloHandlers: [
            [
              instanceExternalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationInstanceCreateMutationPopulator()),
            ],
            [
              externalInstanceAuditEventDestinationHeaderCreate,
              jest
                .fn()
                .mockResolvedValueOnce(destinationInstanceHeaderCreateMutationPopulator())
                .mockResolvedValue(destinationInstanceHeaderCreateMutationPopulator([errorMsg])),
            ],
            [
              deleteInstanceExternalDestination,
              jest.fn().mockResolvedValue(destinationInstanceDeleteMutationPopulator()),
            ],
          ],
        });

        await submitFormWithHeaders();

        expect(findAlertErrors()).toHaveLength(1);
        expect(findAlertErrors().at(0).text()).toBe(errorMsg);
        expect(wrapper.emitted('error')).toBeDefined();
        expect(wrapper.emitted('added')).toBeUndefined();
      });

      it('should not emit add destination event and reports error when network error occurs while adding headers', async () => {
        const sentryError = new Error('Network error');
        const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
        createComponent({
          mountFn: mountExtended,
          apolloHandlers: [
            [
              instanceExternalAuditEventDestinationCreate,
              jest.fn().mockResolvedValue(destinationInstanceCreateMutationPopulator()),
            ],
            [
              externalInstanceAuditEventDestinationHeaderCreate,
              jest
                .fn()
                .mockResolvedValueOnce(destinationInstanceHeaderCreateMutationPopulator())
                .mockRejectedValue(sentryError),
            ],
            [
              deleteInstanceExternalDestination,
              jest.fn().mockResolvedValue(destinationInstanceDeleteMutationPopulator()),
            ],
          ],
        });

        await submitFormWithHeaders();

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

    describe('HTTP headers table', () => {
      beforeEach(() => {
        createComponent({ mountFn: mountExtended });
      });

      it('should add a new blank row if the add row button is clicked', async () => {
        expect(findHeadersRows()).toHaveLength(0);

        await findAddHeaderBtn().trigger('click');

        expect(findHeadersRows()).toHaveLength(1);
      });

      it.each`
        name     | value    | disabled
        ${''}    | ${''}    | ${true}
        ${'abc'} | ${''}    | ${true}
        ${''}    | ${'abc'} | ${true}
        ${'abc'} | ${'abc'} | ${false}
      `(
        'should enable the add button only when both the name and value are filled',
        async ({ name, value, disabled }) => {
          findDestinationName().setValue('Name');
          findDestinationUrl().setValue('https://example.test');
          await findAddHeaderBtn().trigger('click');
          await setHeadersRowData(0, { name, value });

          expect(findSubmitStreamBtn().props('disabled')).toBe(disabled);
        },
      );

      it('disables add button when there are headers with the same name', async () => {
        findDestinationName().setValue('Name');
        findDestinationUrl().setValue('https://example.test');
        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(0, { name: 'a', value: 'b' });

        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(1, { name: 'a', value: 'c' });
        expect(findSubmitStreamBtn().props('disabled')).toBe(true);
      });

      it('should delete a row when the delete button is clicked', async () => {
        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(0, { name: 'row header', value: 'row value' });
        await findAddHeaderBtn().trigger('click');
        await setHeadersRowData(1, { name: 'row header 2', value: 'row value 2' });
        await findAddHeaderBtn().trigger('click');

        expect(findHeadersRows()).toHaveLength(3);

        await findHeaderDeleteBtn(1).trigger('click');

        expect(findHeadersRows()).toHaveLength(2);
        expect(findHeaderNameInput(0).element.value).toBe('row header');
        expect(findHeaderValueInput(0).element.value).toBe('row value');
        expect(findHeaderNameInput(1).element.value).toBe('');
        expect(findHeaderValueInput(1).element.value).toBe('');
      });

      it('should show the maximum number of rows message only when the maximum is reached', async () => {
        await findAddHeaderBtn().trigger('click');
        await findAddHeaderBtn().trigger('click');

        expect(findMaximumHeadersText().exists()).toBe(false);

        await findAddHeaderBtn().trigger('click');

        expect(findHeadersRows()).toHaveLength(maxHeaders);
        expect(findAddHeaderBtn().exists()).toBe(false);
        expect(findMaximumHeadersText().text()).toMatchInterpolatedText(
          sprintf(ADD_STREAM_EDITOR_I18N.MAXIMUM_HEADERS_TEXT, { number: maxHeaders }),
        );
      });
    });

    describe('when editing an existing destination', () => {
      const item = {
        ...mockInstanceExternalDestinations[0],
        headers: {
          nodes: [mockInstanceExternalDestinationHeader(), mockInstanceExternalDestinationHeader()],
        },
      };

      describe('renders', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended, props: { item } });
        });

        it('renders the delete modal', () => {
          expect(findDeleteModal().exists()).toBe(true);
          expect(findDeleteModal().props('item')).toBe(item);
        });

        it('should not render the destinations warning', () => {
          expect(findWarningMessage().exists()).toBe(false);
        });

        it('disables the destination URL field', () => {
          expect(findDestinationUrl().element.value).toBe(
            mockInstanceExternalDestinations[0].destinationUrl,
          );
          expect(findDestinationUrl().attributes('disabled')).toBeDefined();
        });

        it('renders verification token and clipboard button', () => {
          expect(findVerificationTokenFormGroup().classes('gl-max-w-34')).toBe(true);
          expect(findVerificationToken().attributes('readonly')).toBeDefined();
          expect(findVerificationToken().props('value')).toBe(item.verificationToken);
          expect(findClipboardButton().props('text')).toBe(item.verificationToken);
          expect(findClipboardButton().props('title')).toBe('Copy to clipboard');
        });

        it('changes the save button text', () => {
          expect(findSubmitStreamBtn().attributes('name')).toBe(
            ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_NAME,
          );
          expect(findSubmitStreamBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.SAVE_BUTTON_TEXT);
        });

        it('disables the save button text at first', () => {
          expect(findSubmitStreamBtn().props('disabled')).toBe(true);
        });

        it('renders the delete button', () => {
          expect(findDeleteBtn().attributes('name')).toBe(
            ADD_STREAM_EDITOR_I18N.DELETE_BUTTON_TEXT,
          );
          expect(findDeleteBtn().classes('gl-ml-auto')).toBe(true);
          expect(findDeleteBtn().props('variant')).toBe('danger');
          expect(findDeleteBtn().text()).toBe(ADD_STREAM_EDITOR_I18N.DELETE_BUTTON_TEXT);
        });
      });

      describe('update destinations headers', () => {
        const updatedHeader = { ...item.headers.nodes[0], newValue: 'CHANGED_VALUE' };
        const deletedHeader = item.headers.nodes[1];
        const addedHeader = mockInstanceExternalDestinationHeader();

        const setupUpdatedHeaders = async (updated, added) => {
          findDestinationName().setValue('Name');
          findDestinationUrl().setValue('https://example.test');
          await setHeadersRowData(0, { name: updated.key, value: updated.newValue });
          await findHeaderDeleteBtn(1).trigger('click');
          await findAddHeaderBtn().trigger('click');
          await setHeadersRowData(1, { name: added.key, value: added.value });
          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });

          return waitForPromises();
        };

        it('emits the updated event when the headers are added, updated, and deleted', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceUpdateMutationPopulator());
          const headerCreateSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceHeaderCreateMutationPopulator());
          const headerUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceHeaderUpdateMutationPopulator());
          const headerDeleteSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceHeaderDeleteMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item },
            apolloHandlers: [
              [instanceExternalAuditEventDestinationUpdate, destinationUpdateSpy],
              [externalInstanceAuditEventDestinationHeaderCreate, headerCreateSpy],
              [externalInstanceAuditEventDestinationHeaderUpdate, headerUpdateSpy],
              [externalInstanceAuditEventDestinationHeaderDelete, headerDeleteSpy],
            ],
          });

          await setupUpdatedHeaders(updatedHeader, addedHeader);

          expect(destinationUpdateSpy).toHaveBeenCalledTimes(1);

          expect(headerDeleteSpy).toHaveBeenCalledTimes(1);
          expect(headerDeleteSpy).toHaveBeenCalledWith({
            headerId: deletedHeader.id,
          });
          expect(headerUpdateSpy).toHaveBeenCalledTimes(1);
          expect(headerUpdateSpy).toHaveBeenCalledWith({
            headerId: updatedHeader.id,
            key: updatedHeader.key,
            value: updatedHeader.newValue,
            active: false,
          });
          expect(headerCreateSpy).toHaveBeenCalledTimes(1);
          expect(headerCreateSpy).toHaveBeenCalledWith({
            destinationId: item.id,
            key: addedHeader.key,
            value: addedHeader.value,
            active: true,
          });

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('should not emit updated event and reports error when server returns error while saving', async () => {
          const errorMsg =
            'An error occurred when updating external audit event stream destination. Please try it again.';

          createComponent({
            mountFn: mountExtended,
            props: { item },
            apolloHandlers: [
              [
                instanceExternalAuditEventDestinationUpdate,
                jest.fn().mockResolvedValue(destinationInstanceUpdateMutationPopulator()),
              ],
              [
                externalInstanceAuditEventDestinationHeaderCreate,
                jest
                  .fn()
                  .mockResolvedValue(destinationInstanceHeaderCreateMutationPopulator([errorMsg])),
              ],
              [
                externalInstanceAuditEventDestinationHeaderUpdate,
                jest.fn().mockResolvedValue(destinationInstanceHeaderUpdateMutationPopulator()),
              ],
              [
                externalInstanceAuditEventDestinationHeaderDelete,
                jest.fn().mockResolvedValue(destinationInstanceHeaderDeleteMutationPopulator()),
              ],
            ],
          });

          await setupUpdatedHeaders(updatedHeader, addedHeader);

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(errorMsg);
          expect(wrapper.emitted('error')).toBeDefined();
          expect(wrapper.emitted('updated')).toBeUndefined();
        });

        it('should not emit updated event and reports error when network error occurs while saving', async () => {
          const sentryError = new Error('Network error');
          const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');

          createComponent({
            mountFn: mountExtended,
            props: { item },
            apolloHandlers: [
              [
                instanceExternalAuditEventDestinationUpdate,
                jest.fn().mockResolvedValue(destinationInstanceUpdateMutationPopulator()),
              ],
              [
                externalInstanceAuditEventDestinationHeaderUpdate,
                jest.fn().mockRejectedValue(sentryError),
              ],
              [
                externalInstanceAuditEventDestinationHeaderDelete,
                jest.fn().mockResolvedValue(destinationInstanceHeaderDeleteMutationPopulator()),
              ],
            ],
          });

          await setupUpdatedHeaders(updatedHeader, addedHeader);

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
          expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
          expect(wrapper.emitted('error')).toBeDefined();
          expect(wrapper.emitted('updated')).toBeUndefined();
        });
      });

      describe('deleting', () => {
        beforeEach(() => {
          createComponent({ mountFn: mountExtended, props: { item } });
        });

        it('should emit deleted on success operation', async () => {
          const deleteButton = findDeleteBtn();
          await deleteButton.trigger('click');
          await findDeleteModal().vm.$emit('deleting');

          expect(deleteButton.props('loading')).toBe(true);

          await findDeleteModal().vm.$emit('delete');

          expect(deleteButton.props('loading')).toBe(false);
          expect(wrapper.emitted('deleted')).toEqual([[item.id]]);
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
    });

    describe('destination event filters', () => {
      describe('renders', () => {
        beforeEach(() => {
          createComponent({
            mountFn: mountExtended,
            props: { item: mockInstanceExternalDestinations[1] },
          });
        });

        it('displays the correct text', () => {
          expect(findFilteringHeader().text()).toBe(ADD_STREAM_EDITOR_I18N.HEADER_FILTERING);
          expect(findEventTypeFilteringHeader().text()).toBe(
            ADD_STREAM_EDITOR_I18N.FILTER_BY_AUDIT_EVENT_TYPE,
          );
        });

        it('passes selected audit event types to StreamEventTypeFilters', () => {
          expect(findFilters().props()).toStrictEqual({
            value: mockInstanceExternalDestinations[1].eventTypeFilters,
          });
        });
      });

      describe('on change filters', () => {
        it('removes the deselected filters from a destination', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceUpdateMutationPopulator());

          const filterRemoveSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceFilterRemoveMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item: mockInstanceExternalDestinations[1] },
            apolloHandlers: [
              [instanceExternalAuditEventDestinationUpdate, destinationUpdateSpy],
              [deleteInstanceExternalDestinationFilters, filterRemoveSpy],
            ],
          });

          await findFilters().vm.$emit('input', mockRemoveFilterSelect);

          expect(findSubmitStreamBtn().props('disabled')).toBe(false);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(filterRemoveSpy).toHaveBeenCalledWith({
            destinationId: mockInstanceExternalDestinations[1].id,
            eventTypeFilters: mockRemoveFilterRemaining,
          });

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('adds the selected filters for a destination', async () => {
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceUpdateMutationPopulator());

          const filterAddSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceFilterUpdateMutationPopulator());

          createComponent({
            mountFn: mountExtended,
            props: { item: mockInstanceExternalDestinations[1] },
            apolloHandlers: [
              [instanceExternalAuditEventDestinationUpdate, destinationUpdateSpy],
              [addInstanceExternalDestinationFilters, filterAddSpy],
            ],
          });

          await findFilters().vm.$emit('input', mockAddFilterSelect);

          expect(findSubmitStreamBtn().props('disabled')).toBe(false);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(filterAddSpy).toHaveBeenCalledWith({
            destinationId: mockInstanceExternalDestinations[1].id,
            eventTypeFilters: mockAddFilterRemaining,
          });

          expect(findAlertErrors()).toHaveLength(0);
          expect(wrapper.emitted('error')).toBeUndefined();
          expect(wrapper.emitted('updated')).toBeDefined();
        });

        it('should not emit updated event and reports error when network error occurs while saving', async () => {
          const sentryError = new Error('Network error');
          const sentryCaptureExceptionSpy = jest.spyOn(Sentry, 'captureException');
          const destinationUpdateSpy = jest
            .fn()
            .mockResolvedValue(destinationInstanceUpdateMutationPopulator());
          const filterRemoveSpy = jest.fn().mockRejectedValue(sentryError);

          createComponent({
            mountFn: mountExtended,
            props: { item: mockInstanceExternalDestinations[1] },
            apolloHandlers: [
              [instanceExternalAuditEventDestinationUpdate, destinationUpdateSpy],
              [deleteInstanceExternalDestinationFilters, filterRemoveSpy],
            ],
          });

          findFilters().vm.$emit('input', mockRemoveFilterSelect);

          findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors()).toHaveLength(1);
          expect(findAlertErrors().at(0).text()).toBe(AUDIT_STREAMS_NETWORK_ERRORS.UPDATING_ERROR);
          expect(sentryCaptureExceptionSpy).toHaveBeenCalledWith(sentryError);
          expect(wrapper.emitted('error')).toBeDefined();
          expect(wrapper.emitted('updated')).toBeUndefined();
        });
      });
    });
  });
});
