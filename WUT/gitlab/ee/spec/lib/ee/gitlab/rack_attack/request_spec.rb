# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::RackAttack::Request, feature_category: :rate_limiting do
  using RSpec::Parameterized::TableSyntax

  let(:path) { '/' }
  let(:env) { {} }
  let(:request) do
    ::Rack::Attack::Request.new(
      env.reverse_merge(
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => path,
        'rack.input' => StringIO.new
      )
    )
  end

  describe '#should_be_skipped?' do
    where(
      super_value: [true, false],
      geo: [true, false],
      virtual_registries_api_endpoints: [true, false]
    )

    with_them do
      it 'returns true if any condition is true' do
        allow(request).to receive(:api_internal_request?).and_return(super_value)
        allow(request).to receive(:health_check_request?).and_return(super_value)
        allow(request).to receive(:container_registry_event?).and_return(super_value)
        allow(request).to receive(:geo?).and_return(geo)
        allow(request).to receive(:virtual_registries_api_endpoints?).and_return(virtual_registries_api_endpoints)

        expect(request.should_be_skipped?).to be(super_value || geo || virtual_registries_api_endpoints)
      end
    end
  end

  describe '#geo?' do
    subject { request.geo? }

    where(:env, :geo_auth_attempt, :expected) do
      {}                                   | false | false
      {}                                   | true  | false
      { 'HTTP_AUTHORIZATION' => 'secret' } | false | false
      { 'HTTP_AUTHORIZATION' => 'secret' } | true  | true
    end

    with_them do
      before do
        allow(Gitlab::Geo::JwtRequestDecoder).to receive(:geo_auth_attempt?).and_return(geo_auth_attempt)
      end

      it { is_expected.to be(expected) }
    end
  end

  describe '#virtual_registries_api_endpoints?' do
    subject { request.virtual_registries_api_endpoints? }

    ::VirtualRegistries::PACKAGE_TYPES.each do |package_type|
      context "for #{package_type}" do
        let(:path) { "/api/v4/virtual_registries/packages/#{package_type}/555/" }

        before do
          allow(request).to receive(:logical_path).and_return(path)
        end

        it { is_expected.to be(true) }
      end
    end

    where(:path, :expected) do
      '/api/v4/virtual_registries/packages/invalid/555/' | false
      '/api/v4/virtual_registries/packages/maven/test/'  | false
      '/api/v4/virtual_registries/containers/maven/555/' | false
    end

    with_them do
      before do
        allow(request).to receive(:logical_path).and_return(path)
      end

      it { is_expected.to be(expected) }
    end
  end
end
