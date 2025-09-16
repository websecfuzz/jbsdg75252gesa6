import MockAdapter from 'axios-mock-adapter';
import Api from 'ee/api';
import axios from '~/lib/utils/axios_utils';
import { contentTypeMultipartFormData } from '~/lib/utils/headers';
import { HTTP_STATUS_CREATED, HTTP_STATUS_OK } from '~/lib/utils/http_status';

describe('Api', () => {
  const dummyApiVersion = 'v3000';
  const dummyUrlRoot = '/gitlab';

  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    window.gon = {
      api_version: dummyApiVersion,
      relative_url_root: dummyUrlRoot,
    };
  });

  afterEach(() => {
    mock.restore();
  });

  describe('ldapGroups', () => {
    it('returns expected data', async () => {
      const query = 'query';
      const provider = 'provider';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/ldap/${provider}/groups.json`;
      const expectedData = [{ name: 'test' }];

      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, expectedData);
      const response = await Api.ldapGroups(query, provider);

      expect(response.data).toEqual(expectedData);
    });
  });

  describe('createChildEpic', () => {
    it('calls `axios.post` using params `groupId`, `parentEpicIid` and title', async () => {
      const groupId = 'gitlab-org';
      const parentEpicId = 1;
      const title = 'Sample epic';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/epics`;
      const expectedRes = {
        title,
        id: 20,
        parentId: 5,
      };

      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedRes);

      const { data } = await Api.createChildEpic({ groupId, parentEpicId, title });
      expect(data.title).toBe(expectedRes.title);
      expect(data.id).toBe(expectedRes.id);
      expect(data.parentId).toBe(expectedRes.parentId);
    });
  });

  describe('GroupActivityAnalytics', () => {
    const groupId = 'gitlab-org';

    describe('groupActivityMergeRequestsCount', () => {
      it('fetches the number of MRs created for a given group', () => {
        const response = { merge_requests_count: 10 };
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/analytics/group_activity/merge_requests_count`;

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

        return Api.groupActivityMergeRequestsCount(groupId).then(({ data }) => {
          expect(data).toEqual(response);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, { params: { group_path: groupId } });
        });
      });
    });

    describe('groupActivityIssuesCount', () => {
      it('fetches the number of issues created for a given group', async () => {
        const response = { issues_count: 20 };
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/analytics/group_activity/issues_count`;

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, response);

        const { data } = await Api.groupActivityIssuesCount(groupId);
        expect(data).toEqual(response);
        expect(axios.get).toHaveBeenCalledWith(expectedUrl, { params: { group_path: groupId } });
      });
    });

    describe('groupActivityNewMembersCount', () => {
      it('fetches the number of new members created for a given group', () => {
        const response = { new_members_count: 30 };
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/analytics/group_activity/new_members_count`;

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

        return Api.groupActivityNewMembersCount(groupId).then(({ data }) => {
          expect(data).toEqual(response);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, { params: { group_path: groupId } });
        });
      });
    });
  });

  describe('changeVulnerabilityState', () => {
    it.each`
      id    | action
      ${5}  | ${'dismiss'}
      ${7}  | ${'confirm'}
      ${38} | ${'resolve'}
    `('POSTS to correct endpoint ($id, $action)', ({ id, action }) => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/vulnerabilities/${id}/${action}`;
      const expectedResponse = { id, action, test: 'test' };

      mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, expectedResponse);

      return Api.changeVulnerabilityState(id, action).then(({ data }) => {
        expect(mock.history.post).toContainEqual(expect.objectContaining({ url: expectedUrl }));
        expect(data).toEqual(expectedResponse);
      });
    });
  });

  describe('GeoSite', () => {
    let expectedUrl;
    let mockSite;

    beforeEach(() => {
      expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/geo_sites`;
    });

    describe('createGeoSite', () => {
      it('POSTs with correct action', () => {
        mockSite = {
          name: 'Mock Site',
          url: 'https://mock_site.gitlab.com',
          primary: false,
        };

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'post');
        mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_CREATED, mockSite);

        return Api.createGeoSite(mockSite).then(({ data }) => {
          expect(data).toEqual(mockSite);
          expect(axios.post).toHaveBeenCalledWith(expectedUrl, mockSite);
        });
      });
    });

    describe('updateGeoSite', () => {
      it('PUTs with correct action', () => {
        mockSite = {
          id: 1,
          name: 'Mock Site',
          url: 'https://mock_site.gitlab.com',
          primary: false,
        };

        jest.spyOn(Api, 'buildUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'put');
        mock.onPut(`${expectedUrl}/${mockSite.id}`).replyOnce(HTTP_STATUS_CREATED, mockSite);

        return Api.updateGeoSite(mockSite).then(({ data }) => {
          expect(data).toEqual(mockSite);
          expect(axios.put).toHaveBeenCalledWith(`${expectedUrl}/${mockSite.id}`, mockSite);
        });
      });
    });

    describe('removeGeoSite', () => {
      it('DELETES with correct ID', () => {
        mockSite = {
          id: 1,
        };

        jest.spyOn(Api, 'buildUrl').mockReturnValue(`${expectedUrl}/${mockSite.id}`);
        jest.spyOn(axios, 'delete');
        mock.onDelete(`${expectedUrl}/${mockSite.id}`).replyOnce(HTTP_STATUS_OK, {});

        return Api.removeGeoSite(mockSite.id).then(() => {
          expect(axios.delete).toHaveBeenCalledWith(`${expectedUrl}/${mockSite.id}`);
        });
      });
    });
  });

  describe('Project analytics: deployment frequency', () => {
    const projectPath = 'test/project';
    const encodedProjectPath = encodeURIComponent(projectPath);
    const params = { environment: 'production' };
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodedProjectPath}/analytics/deployment_frequency`;

    describe('deploymentFrequencies', () => {
      it('GETs the right url', async () => {
        mock.onGet(expectedUrl, { params }).replyOnce(HTTP_STATUS_OK, []);

        const { data } = await Api.deploymentFrequencies(projectPath, params);

        expect(data).toEqual([]);
      });
    });
  });

  describe('Issue metric images', () => {
    const projectId = 1;
    const issueIid = '2';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/issues/${issueIid}/metric_images`;

    describe('fetchIssueMetricImages', () => {
      it('fetches a list of images', async () => {
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

        await Api.fetchIssueMetricImages({ issueIid, id: projectId }).then(({ data }) => {
          expect(data).toEqual([]);
          expect(axios.get).toHaveBeenCalled();
        });
      });
    });

    describe('uploadIssueMetricImage', () => {
      const file = 'mock file';
      const url = 'mock url';
      const urlText = 'mock urlText';

      it('uploads an image', async () => {
        jest.spyOn(axios, 'post');
        mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, {});

        await Api.uploadIssueMetricImage({ issueIid, id: projectId, file, url, urlText }).then(
          ({ data }) => {
            expect(data).toEqual({});
            expect(axios.post.mock.calls[0][2]).toEqual({
              headers: { ...contentTypeMultipartFormData },
            });
          },
        );
      });
    });
  });

  describe('deployment approvals', () => {
    const projectId = 1;
    const deploymentId = 2;
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/deployments/${deploymentId}/approval`;
    const representedAs = 'Maintainers';
    const comment = 'comment';

    it('sends an approval when approve is true', async () => {
      mock
        .onPost(expectedUrl, { status: 'approved', represented_as: representedAs, comment })
        .replyOnce(HTTP_STATUS_OK);

      await Api.deploymentApproval({
        id: projectId,
        deploymentId,
        approve: true,
        representedAs,
        comment,
      });

      expect(mock.history.post).toHaveLength(1);
      expect(mock.history.post[0].data).toBe(
        JSON.stringify({ status: 'approved', represented_as: representedAs, comment }),
      );
    });

    it('sends a rejection when approve is false', async () => {
      mock
        .onPost(expectedUrl, { status: 'rejected', represented_as: representedAs, comment })
        .replyOnce(HTTP_STATUS_OK);

      await Api.deploymentApproval({
        id: projectId,
        deploymentId,
        approve: false,
        representedAs,
        comment,
      });

      expect(mock.history.post).toHaveLength(1);
      expect(mock.history.post[0].data).toBe(
        JSON.stringify({ status: 'rejected', represented_as: representedAs, comment }),
      );
    });
  });

  describe('validatePaymentMethod', () => {
    it('submits the custom value stream data', () => {
      const response = {};
      const expectedUrl = '/gitlab/-/subscriptions/validate_payment_method';
      mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, response);

      return Api.validatePaymentMethod('id', 'user_id').then((res) => {
        expect(res.data).toEqual(response);
        expect(res.config.url).toEqual(expectedUrl);
      });
    });
  });

  describe('updateCompliancePolicySettings', () => {
    it('updates compliance and policy settings', async () => {
      const settings = { csp_namespace_id: 123 };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/admin/security/compliance_policy_settings`;
      const expectedResponse = { success: true };

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.updateCompliancePolicySettings(settings);

      expect(data).toEqual(expectedResponse);
      expect(mock.history.put).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(settings),
        }),
      );
    });

    it('handles null csp_namespace_id', async () => {
      const settings = { csp_namespace_id: null };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/admin/security/compliance_policy_settings`;
      const expectedResponse = { success: true };

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.updateCompliancePolicySettings(settings);

      expect(data).toEqual(expectedResponse);
      expect(mock.history.put).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(settings),
        }),
      );
    });

    it('handles empty settings object', async () => {
      const settings = {};
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/admin/security/compliance_policy_settings`;
      const expectedResponse = { success: true };

      mock.onPut(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

      const { data } = await Api.updateCompliancePolicySettings(settings);

      expect(data).toEqual(expectedResponse);
      expect(mock.history.put).toContainEqual(
        expect.objectContaining({
          url: expectedUrl,
          data: JSON.stringify(settings),
        }),
      );
    });
  });

  describe('protectedEnvironments', () => {
    it('fetches all protected environments for projects', () => {
      const response = [{ name: 'staging ' }];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/1/protected_environments/`;
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

      return Api.protectedEnvironments(1, 'projects').then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toEqual(expectedUrl);
      });
    });

    it('fetches all protected environments for groups', () => {
      const response = [{ name: 'staging ' }];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/1/protected_environments/`;
      mock.onGet(expectedUrl).reply(HTTP_STATUS_OK, response);

      return Api.protectedEnvironments(1, 'groups').then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toEqual(expectedUrl);
      });
    });
  });

  describe('updateProtectedEnvironment', () => {
    it('puts changes to a protected environment for projects', () => {
      const response = { name: 'staging' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/1/protected_environments/staging`;
      mock.onPut(expectedUrl, response).reply(HTTP_STATUS_OK, response);

      return Api.updateProtectedEnvironment(1, 'projects', response).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });

    it('puts changes to a protected environment for groups', () => {
      const response = { name: 'staging' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/1/protected_environments/staging`;
      mock.onPut(expectedUrl, response).reply(HTTP_STATUS_OK, response);

      return Api.updateProtectedEnvironment(1, 'groups', response).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });
  });

  describe('deleteProtectedEnvironment', () => {
    it('deletes a protected environment for projects', () => {
      const environment = { name: 'staging' };
      const response = {};
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/1/protected_environments/staging`;
      mock.onDelete(expectedUrl, environment).reply(HTTP_STATUS_OK, response);

      return Api.deleteProtectedEnvironment(1, 'projects', environment).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });

    it('deletes a protected environment for groups', () => {
      const environment = { name: 'staging' };
      const response = {};
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/1/protected_environments/staging`;
      mock.onDelete(expectedUrl, environment).reply(HTTP_STATUS_OK, response);

      return Api.deleteProtectedEnvironment(1, 'groups', environment).then(({ data, config }) => {
        expect(data).toEqual(response);
        expect(config.url).toBe(expectedUrl);
      });
    });
  });

  describe('AI endpoints', () => {
    const model = 'test-model';
    const prompt = 'test-prompt';
    const msg = 'foo bar';
    const rest = { max_tokens: 50, temperature: 0.5 };

    describe('requestAICompletions', () => {
      it('queries the completions AI endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.aiCompletionsPath);
        const expectedResponse = { choices: { text: msg } };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestAICompletions({ model, prompt, ...rest }).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });

    describe('requestAIEmbeddings', () => {
      it('queries the completions AI endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.aiEmbeddingsPath);
        const expectedResponse = { data: [{ embedding: [msg] }] };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestAIEmbeddings({ model, input: prompt, ...rest }).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });

    describe('requestAIChat', () => {
      it('queries the completions AI endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.aiChatPath);
        const expectedResponse = { choices: { message: msg } };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestAIChat({ model, messages: [msg], ...rest }).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });

    describe('requestTanukiBotResponse', () => {
      it('sends a POST request to the tanuki bot endpoint', () => {
        const expectedUrl = Api.buildUrl(Api.tanukiBotAskPath);
        const expectedResponse = { msg };
        mock.onPost(expectedUrl).reply(HTTP_STATUS_OK, expectedResponse);

        return Api.requestTanukiBotResponse(msg).then((res) => {
          expect(res.data).toEqual(expectedResponse);
          expect(res.config.url).toEqual(expectedUrl);
        });
      });
    });
  });
});
