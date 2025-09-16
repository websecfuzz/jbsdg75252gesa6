import MockAdapter from 'axios-mock-adapter';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

describe('SubscriptionsApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('Hand raise leads', () => {
    describe('sendHandRaiseLead', () => {
      const expectedUrl = `/-/gitlab_subscriptions/hand_raise_leads`;
      const params = {
        namespaceId: 1000,
        companyName: 'ACME',
        firstName: 'Joe',
        lastName: 'Doe',
        phoneNumber: '1-234567890',
        country: 'US',
        state: 'CA',
        comment: 'A comment',
        glmContent: 'some-content',
        productInteraction: '_product_interaction_',
      };
      const formParams = {
        namespace_id: 1000,
        company_name: 'ACME',
        first_name: 'Joe',
        last_name: 'Doe',
        phone_number: '1-234567890',
        country: 'US',
        state: 'CA',
        comment: 'A comment',
        glm_content: 'some-content',
        product_interaction: '_product_interaction_',
      };

      it('sends hand raise lead parameters', async () => {
        jest.spyOn(axios, 'post');
        mock.onPost(expectedUrl).replyOnce(HTTP_STATUS_OK, []);

        const { data } = await SubscriptionsApi.sendHandRaiseLead(expectedUrl, params);

        expect(data).toEqual([]);
        expect(axios.post).toHaveBeenCalledWith(expectedUrl, formParams);
      });
    });
  });
});
