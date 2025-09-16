# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Maven Registry Upstream', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }
  let_it_be(:query) do
    %(
        query {
          group(fullPath: "#{group.full_path}") {
            mavenVirtualRegistries {
              nodes {
                id
                name
                upstreams {
                  id
                  name
                  registryUpstreams {
                    id
                    position
                  }
                }
              }
            }
          }
        }
      )
  end

  subject(:query_result) { GitlabSchema.execute(query, context: { current_user: current_user }).as_json }

  before do
    group.add_member(current_user, Gitlab::Access::MAINTAINER)
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  it 'returns registry upstreams for an upstream' do
    maven_registries = query_result.dig(*%w[data group mavenVirtualRegistries nodes])
    upstreams = maven_registries[0]['upstreams']
    registry_upstreams = upstreams[0]['registryUpstreams']

    expect(registry_upstreams.length).to be 1
    expect(registry_upstreams[0]["position"]).to be 1
  end

  context 'with feature flag maven_virtual_registry disabled' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    it 'returns no maven virtual registries' do
      maven_registries = query_result.dig(*%w[data group mavenVirtualRegistries nodes])

      expect(maven_registries).to be_nil
    end
  end
end
