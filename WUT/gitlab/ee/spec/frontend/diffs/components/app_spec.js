import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getMRCodequalityAndSecurityReports from 'ee_else_ce/diffs/components/graphql/get_mr_codequality_and_security_reports.query.graphql';
import { TEST_HOST } from 'spec/test_constants';
import App, { FINDINGS_POLL_INTERVAL } from '~/diffs/components/app.vue';
import DiffFile from '~/diffs/components/diff_file.vue';
import vuexStore from 'helpers/mocks/mr_notes/stores';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';
import {
  codeQualityNewErrorsHandler,
  SASTParsedHandler,
  SASTParsingAndParsedHandler,
  SASTErrorHandler,
  codeQualityErrorAndParsed,
  requestError,
  SAST_REPORT_DATA,
} from './mocks/queries';

const TEST_ENDPOINT = `${TEST_HOST}/diff/endpoint`;

Vue.use(Vuex);
Vue.use(VueApollo);
Vue.use(PiniaVuePlugin);

describe('diffs/components/app', () => {
  let fakeApollo;
  let wrapper;
  let pinia;
  let store;

  const createComponent = ({ props = {}, queryHandler = codeQualityNewErrorsHandler } = {}) => {
    vuexStore.reset();
    vuexStore.getters.isNotesFetched = false;
    vuexStore.getters.getNoteableData = {
      current_user: {
        can_create_note: true,
      },
    };
    vuexStore.getters['findingsDrawer/activeDrawer'] = {};

    vuexStore.state.findingsDrawer = { activeDrawer: false };

    fakeApollo = createMockApollo([[getMRCodequalityAndSecurityReports, queryHandler]]);

    wrapper = shallowMount(App, {
      apolloProvider: fakeApollo,
      propsData: {
        shouldShow: true,
        endpointCoverage: `${TEST_HOST}/diff/endpointCoverage`,
        endpointCodequality: '',
        sastReportAvailable: false,
        currentUser: {},
        changesEmptyStateIllustration: '',
        ...props,
      },
      mocks: {
        $store: vuexStore,
      },
      pinia,
    });
  };

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });

    store = useLegacyDiffs();

    store.isLoading = false;
    store.isTreeLoaded = true;

    store.setBaseConfig({
      endpoint: TEST_ENDPOINT,
      endpointMetadata: `${TEST_HOST}/diff/endpointMetadata`,
      endpointBatch: `${TEST_HOST}/diff/endpointBatch`,
      endpointDiffForPath: TEST_ENDPOINT,
      projectPath: 'namespace/project',
      dismissEndpoint: '',
      showSuggestPopover: true,
      mrReviews: {},
    });

    store.fetchDiffFilesMeta.mockResolvedValue({ real_size: '20' });
    store.fetchDiffFilesBatch.mockResolvedValue();
    store.assignDiscussionsToDiff.mockResolvedValue();

    useNotes();
  });

  describe('EE codequality diff', () => {
    it('polls Code Quality data via GraphQL and not via REST when codequalityReportAvailable is true', async () => {
      createComponent({
        props: { codequalityReportAvailable: true },
        queryHandler: codeQualityErrorAndParsed,
      });
      await waitForPromises();
      expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(2);
    });

    it('does not poll Code Quality data via GraphQL when codequalityReportAvailable is false', async () => {
      createComponent({ props: { codequalityReportAvailable: false } });
      await waitForPromises();
      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(0);
    });

    it('stops polling when newErrors in response are defined', async () => {
      createComponent({ props: { codequalityReportAvailable: true } });

      await waitForPromises();

      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(codeQualityNewErrorsHandler).toHaveBeenCalledTimes(1);
    });

    it('does not fetch code quality data when endpoint is blank', () => {
      createComponent({ props: { shouldShow: false, endpointCodequality: '' } });
      expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
    });
  });

  describe('EE SAST diff', () => {
    it('polls SAST data when sastReportAvailable is true', async () => {
      createComponent({
        props: { sastReportAvailable: true },
        queryHandler: SASTParsingAndParsedHandler,
      });
      await waitForPromises();

      expect(SASTParsingAndParsedHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTParsingAndParsedHandler).toHaveBeenCalledTimes(2);
    });

    it('stops polling when sastReport status is PARSED', async () => {
      createComponent({
        props: { sastReportAvailable: true },
        queryHandler: SASTParsedHandler,
      });

      await waitForPromises();

      expect(SASTParsedHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTParsedHandler).toHaveBeenCalledTimes(1);
    });

    it('stops polling on request error', async () => {
      createComponent({
        props: { sastReportAvailable: true },
        queryHandler: requestError,
      });
      await waitForPromises();

      expect(requestError).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(requestError).toHaveBeenCalledTimes(1);
    });

    it('stops polling on response status error', async () => {
      createComponent({
        props: { sastReportAvailable: true },
        queryHandler: SASTErrorHandler,
      });
      await waitForPromises();

      expect(SASTErrorHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

      expect(SASTErrorHandler).toHaveBeenCalledTimes(1);
    });

    it('does not fetch SAST data when sastReportAvailable is false', () => {
      createComponent({ props: { shouldShow: false } });
      expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
    });

    it('passes the SAST report-data to the diff component', async () => {
      store.viewDiffsFileByFile = true;
      store.diffFiles = [{ file_hash: '123' }];
      store.treeEntries = { 123: { type: 'blob', id: 123, file_hash: '123' } };
      store.virtualScrollerDisabled = true;
      createComponent({
        props: {
          sastReportAvailable: true,
        },
        queryHandler: SASTParsedHandler,
      });

      await waitForPromises();

      expect(wrapper.findComponent(DiffFile).props('sastData')).toEqual(SAST_REPORT_DATA);
    });
  });
});
