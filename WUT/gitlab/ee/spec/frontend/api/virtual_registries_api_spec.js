import MockAdapter from 'axios-mock-adapter';
import * as VirtualRegistryApi from 'ee/api/virtual_registries_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

const dummyApiVersion = 'v3000';
const dummyUrlRoot = '/gitlab';

describe('VirtualRegistriesApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: dummyApiVersion,
      relative_url_root: dummyUrlRoot,
    };
    jest.spyOn(axios, 'get');
    jest.spyOn(axios, 'delete');
  });

  afterEach(() => {
    mock.restore();
  });

  describe('getMavenRegistriesList', () => {
    it('fetches the maven registries of the root group', () => {
      const requestPath = 'virtual_registries/packages/maven/registries';
      const namespaceId = 'flightjs';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${namespaceId}/-/${requestPath}`;
      const expectedParams = {
        id: namespaceId,
      };
      const expectResponse = [
        {
          id: 4,
          name: 'app-test',
          description: 'app description',
          group_id: 283,
          created_at: '2025-04-29T13:06:01.609Z',
          updated_at: '2025-05-02T04:00:15.442Z',
        },
      ];
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectResponse);

      return VirtualRegistryApi.getMavenVirtualRegistriesList(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectResponse);
      });
    });
  });

  describe('updateMavenUpstream', () => {
    it('updates the maven upstream', () => {
      const requestPath = 'virtual_registries/packages/maven/upstreams';
      const upstreamId = 1;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}`;
      const expectedData = {
        id: upstreamId,
        name: 'new name',
        description: 'new description',
      };
      const expectedParams = {
        id: upstreamId,
        data: expectedData,
      };
      const expectResponse = {
        id: upstreamId,
        name: expectedData.name,
        description: expectedData.description,
      };
      mock.onPatch(expectedUrl).reply(HTTP_STATUS_OK, expectResponse);

      return VirtualRegistryApi.updateMavenUpstream(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectResponse);
      });
    });
  });

  describe('deleteMavenUpstream', () => {
    it('deletes the maven upstream', () => {
      const requestPath = 'virtual_registries/packages/maven/upstreams';
      const upstreamId = 1;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}`;
      const expectedParams = {
        id: upstreamId,
      };
      const expectedResponse = {};
      mock.onDelete(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      return VirtualRegistryApi.deleteMavenUpstream(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectedResponse);
      });
    });
  });

  describe('getMavenUpstreamCacheEntries', () => {
    it('fetches the maven upstream cache entries', () => {
      const requestPath = 'virtual_registries/packages/maven/upstreams';
      const upstreamId = '5';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}/cache_entries`;
      const expectedParams = {
        id: upstreamId,
      };
      const expectResponse = [
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
      ];
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectResponse);

      return VirtualRegistryApi.getMavenUpstreamCacheEntries(expectedParams).then(({ data }) => {
        expect(data).toEqual(expectResponse);
      });
    });
  });

  describe('deleteMavenUpstreamCacheEntry', () => {
    it('deletes upstream cache entry', async () => {
      const requestPath = 'virtual_registries/packages/maven/cache_entries';
      const upstreamId = '5';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/${requestPath}/${upstreamId}`;
      const expectedParams = {
        id: upstreamId,
      };

      mock.onDelete(expectedUrl).reply(HTTP_STATUS_OK, []);

      const { data } = await VirtualRegistryApi.deleteMavenUpstreamCacheEntry(expectedParams);

      expect(data).toEqual([]);
      expect(axios.delete).toHaveBeenCalledWith(expectedUrl);
    });
  });
});
