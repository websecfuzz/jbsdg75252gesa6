# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SubscriptionPortal::Clients::Rest, feature_category: :subscription_management do
  let(:client) { Gitlab::SubscriptionPortal::Client }
  let(:message) { nil }
  let(:http_method) { :post }
  let(:response) { nil }
  let(:parsed_response) { nil }
  let(:gitlab_http_response) do
    instance_double(
      HTTParty::Response,
      code: response.code,
      response: response,
      body: {},
      parsed_response: parsed_response
    )
  end

  let(:headers) do
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'X-Admin-Email' => 'gl_com_api@gitlab.com',
      'X-Admin-Token' => 'customer_admin_token',
      'User-Agent' => "GitLab/#{Gitlab::VERSION}"
    }
  end

  before do
    stub_env('GITLAB_QA_USER_AGENT', nil)
  end

  shared_examples 'when response is successful' do
    let(:response) { Net::HTTPSuccess.new(1.0, '201', 'OK') }

    it 'has a successful status' do
      url = "#{::Gitlab::Routing.url_helpers.subscription_portal_url}/#{route_path}"
      allow(Gitlab::HTTP).to receive(http_method)
        .with(url, instance_of(Hash))
        .and_return(gitlab_http_response)

      expect(subject[:success]).to eq(true)
    end
  end

  shared_examples 'when http call raises an exception' do
    let(:message) { 'Our team has been notified. Please try again.' }

    it 'overrides the error message' do
      exception = Gitlab::HTTP::HTTP_ERRORS.first.new
      allow(Gitlab::HTTP).to receive(http_method).and_raise(exception)

      expect(subject[:success]).to eq(false)
      expect(subject[:data][:errors]).to eq(message)
    end
  end

  shared_examples 'when response code is 422' do
    let(:response) { Net::HTTPUnprocessableEntity.new(1.0, '422', 'Error') }
    let(:message) { 'Email has already been taken' }
    let(:error_attribute_map) { { "email" => ["taken"] } }
    let(:parsed_response) { { errors: message, error_attribute_map: error_attribute_map }.stringify_keys }

    it 'has a unprocessable entity status' do
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
      allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

      expect(subject[:success]).to eq(false)

      expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
        instance_of(::Gitlab::SubscriptionPortal::Client::ResponseError),
        { status: response.code, message: parsed_response, body: {} }
      )
    end

    it 'returns the error message along with the error_attribute_map' do
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
      allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

      expect(subject[:success]).to eq(false)
      expect(subject[:data][:errors]).to eq(message)
      expect(subject[:data][:error_attribute_map]).to eq(error_attribute_map)
    end
  end

  shared_examples 'when response code is 500' do
    let(:response) { Net::HTTPServerError.new(1.0, '500', 'Error') }

    it 'has a server error status' do
      allow(Gitlab::ErrorTracking).to receive(:log_exception)
      allow(Gitlab::HTTP).to receive(http_method).and_return(gitlab_http_response)

      expect(subject[:success]).to eq(false)

      expect(Gitlab::ErrorTracking).to have_received(:log_exception).with(
        instance_of(::Gitlab::SubscriptionPortal::Client::ResponseError),
        { status: response.code, message: "HTTP status code: #{response.code}", body: {} }
      )
    end
  end

  shared_examples 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header' do
    let(:response) { Net::HTTPSuccess.new(1.0, '201', 'OK') }

    it 'sends the default User-Agent' do
      headers['User-Agent'] = "GitLab/#{Gitlab::VERSION}"

      expect(Gitlab::HTTP).to receive(http_method).with(anything,
        hash_including(headers: headers)).and_return(gitlab_http_response)

      subject
    end

    it 'sends GITLAB_QA_USER_AGENT env variable value in the "User-Agent" header' do
      expected_headers = headers.merge({ 'User-Agent' => 'GitLab/QA' })

      stub_env('GITLAB_QA_USER_AGENT', 'GitLab/QA')

      expect(Gitlab::HTTP).to receive(http_method).with(anything,
        hash_including(headers: expected_headers)).and_return(gitlab_http_response)

      subject
    end
  end

  describe '#generate_trial' do
    subject do
      client.generate_trial({})
    end

    let(:route_path) { 'trials' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

    it "nests in the trial_user param if needed" do
      expect(client).to receive(:http_post).with('trials', anything, { trial_user: { foo: 'bar' } })

      client.generate_trial(foo: 'bar')
    end
  end

  describe '#generate_addon_trial' do
    subject do
      client.generate_addon_trial({})
    end

    let(:route_path) { 'trials/create_addon' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'

    it "nests in the trial_user param if needed" do
      expect(client).to receive(:http_post).with('trials/create_addon', anything, { trial_user: { foo: 'bar' } })

      client.generate_addon_trial(foo: 'bar')
    end
  end

  describe '#generate_lead' do
    subject do
      client.generate_lead({})
    end

    let(:route_path) { 'trials/create_hand_raise_lead' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#generate_iterable' do
    subject do
      client.generate_iterable({})
    end

    let(:route_path) { 'trials/create_iterable' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#opt_in_lead' do
    subject do
      client.opt_in_lead({})
    end

    let(:route_path) { 'api/marketo_leads/opt_in' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
  end

  describe '#create_subscription' do
    subject do
      client.create_subscription({}, 'customer@example.com', 'token')
    end

    let(:route_path) { 'subscriptions' }
    let(:headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'X-Customer-Email' => 'customer@example.com',
        'X-Customer-Token' => 'token'
      }
    end

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#create_customer' do
    subject do
      client.create_customer({})
    end

    let(:route_path) { 'api/customers' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#payment_form_params' do
    subject do
      client.payment_form_params('cc', 123)
    end

    let(:http_method) { :get }
    let(:route_path) { 'payment_forms/cc' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#payment_method' do
    subject do
      client.payment_method('1')
    end

    let(:http_method) { :get }
    let(:route_path) { 'api/payment_methods/1' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#validate_payment_method' do
    subject do
      client.validate_payment_method('test_payment_method_id', {})
    end

    let(:http_method) { :post }
    let(:route_path) { 'api/payment_methods/test_payment_method_id/validate' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#customers_oauth_app_uid' do
    subject do
      client.customers_oauth_app_uid
    end

    let(:http_method) { :get }
    let(:route_path) { 'api/v1/oauth_app_id' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#create_seat_link' do
    subject do
      seat_link_data = Gitlab::SeatLinkData.new(
        timestamp: Time.current,
        key: 'license_key',
        max_users: 5,
        billable_users_count: 4)

      client.create_seat_link(seat_link_data)
    end

    let(:http_method) { :post }
    let(:route_path) { 'api/v1/seat_links' }
    let(:headers) do
      {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'User-Agent' => "GitLab/#{Gitlab::VERSION}"
      }
    end

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end

  describe '#namespace_eligible_trials' do
    subject do
      client.namespace_eligible_trials(namespace_ids: ['1'])
    end

    let(:http_method) { :get }
    let(:route_path) { 'api/v1/gitlab/namespaces/trials/eligibility' }

    it_behaves_like 'when response is successful'
    it_behaves_like 'when response code is 422'
    it_behaves_like 'when response code is 500'
    it_behaves_like 'when http call raises an exception'
    it_behaves_like 'a request that sends the GITLAB_QA_USER_AGENT value in the "User-Agent" header'
  end
end
