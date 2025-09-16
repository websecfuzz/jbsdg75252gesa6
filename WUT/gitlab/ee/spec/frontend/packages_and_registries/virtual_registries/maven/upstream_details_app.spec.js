import { GlFilteredSearch, GlLoadingIcon, GlPagination } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  getMavenUpstreamCacheEntries,
  deleteMavenUpstreamCacheEntry,
} from 'ee/api/virtual_registries_api';
import UpstreamDetailsApp from 'ee/packages_and_registries/virtual_registries/maven/upstream_details_app.vue';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/upstream_details_header.vue';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/cache_entries_table.vue';
import { createAlert } from '~/alert';
import * as urlUtils from '~/lib/utils/url_utility';
import { TEST_HOST } from 'spec/test_constants';
import { mockCacheEntries, mockUpstreamPagination } from '../mock_data';

jest.mock('~/alert');
jest.mock('ee/api/virtual_registries_api', () => ({
  getMavenUpstreamCacheEntries: jest.fn(),
  deleteMavenUpstreamCacheEntry: jest.fn(),
}));

describe('UpstreamDetailsApp', () => {
  let wrapper;

  const defaultProvide = {
    upstream: {
      id: 5,
      name: 'Test Maven Upstream',
      url: 'https://maven.example.com',
      description: 'This is a test maven upstream',
      cacheEntriesCount: 2,
    },
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findTable = () => wrapper.findComponent(CacheEntriesTable);
  const findHeader = () => wrapper.findComponent(UpstreamDetailsHeader);
  const findPagination = () => wrapper.findComponent(GlPagination);

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(UpstreamDetailsApp, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  beforeEach(() => {
    getMavenUpstreamCacheEntries.mockReset();
    deleteMavenUpstreamCacheEntry.mockReset();
  });

  describe('loading', () => {
    it('renders loading icon', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('component rendering', () => {
    beforeEach(async () => {
      getMavenUpstreamCacheEntries.mockResolvedValue({ data: mockCacheEntries });

      createComponent();

      await waitForPromises();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders details header', () => {
      expect(findHeader().props('upstream')).toEqual({
        id: 5,
        name: 'Test Maven Upstream',
        url: 'https://maven.example.com',
        description: 'This is a test maven upstream',
        cacheEntriesCount: 2,
      });
    });

    it('renders cache entries table', () => {
      expect(findTable().props('cacheEntries')).toEqual([
        {
          id: 'NSAvdGVzdC9iYXI=',
          group_id: 209,
          upstream_id: 5,
          upstream_checked_at: '2025-05-19T14:22:23.048Z',
          file_md5: null,
          file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83',
          size: 15,
          relative_path: '/test/bar',
          upstream_etag: null,
          content_type: 'application/octet-stream',
          created_at: '2025-05-19T14:22:23.050Z',
          updated_at: '2025-05-19T14:22:23.050Z',
        },
      ]);
    });

    it('does not display pagination', () => {
      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('filtered search', () => {
    beforeEach(async () => {
      getMavenUpstreamCacheEntries.mockResolvedValue({ data: mockCacheEntries });

      createComponent();

      await waitForPromises();
    });

    it('renders filter search', () => {
      expect(findFilteredSearch().exists()).toBe(true);
    });

    it('searches for artifact relative path', async () => {
      jest.spyOn(urlUtils, 'updateHistory');

      findFilteredSearch().vm.$emit('submit', ['foo']);

      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(getMavenUpstreamCacheEntries).toHaveBeenCalledWith({
        id: 5,
        params: { search: 'foo', page: 1, per_page: 20 },
      });
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?search=foo&page=1`,
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      getMavenUpstreamCacheEntries.mockResolvedValue({ data: mockCacheEntries });

      createComponent({ upstream: mockUpstreamPagination });

      await waitForPromises();
    });

    it('displays pagination', () => {
      expect(findPagination().exists()).toBe(true);
      expect(findPagination().props()).toMatchObject({ value: 1, perPage: 20, totalItems: 22 });
    });

    it('paginates for page based data', async () => {
      jest.spyOn(urlUtils, 'updateHistory');

      findPagination().vm.$emit('input', 2);

      await waitForPromises();

      expect(getMavenUpstreamCacheEntries).toHaveBeenCalledWith({
        id: 5,
        params: { page: 2, per_page: 20 },
      });
      expect(urlUtils.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/?page=2`,
      });
    });
  });

  describe('actions', () => {
    it('deletes upstream artifact', async () => {
      getMavenUpstreamCacheEntries.mockResolvedValue({ data: mockCacheEntries });

      createComponent();

      await waitForPromises();

      findTable().vm.$emit('delete', { id: 5 });

      expect(deleteMavenUpstreamCacheEntry).toHaveBeenCalledWith({ id: 5 });
    });
  });

  describe('error state', () => {
    it('shows error message on failed attempt to get cached entries', async () => {
      const error = new Error('API Error');

      getMavenUpstreamCacheEntries.mockRejectedValue(error);

      createComponent();

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to fetch cache entries.',
        error,
        captureError: true,
      });
    });

    it('shows error message on failed attempt to search cached entries', async () => {
      const error = new Error('API Error');

      getMavenUpstreamCacheEntries.mockRejectedValue(error);

      createComponent();

      await waitForPromises();

      findFilteredSearch().vm.$emit('submit', ['foo']);

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to search cache entries.',
        error,
        captureError: true,
      });
    });

    it('shows error message on failed attempt to delete upstream artifact', async () => {
      const error = new Error('API Error');

      deleteMavenUpstreamCacheEntry.mockRejectedValue(error);

      createComponent();

      await waitForPromises();

      findTable().vm.$emit('delete', { id: 5 });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to delete cache entry.',
        error,
        captureError: true,
      });
    });
  });
});
