# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MavenVirtualRegistry'], feature_category: :virtual_registry do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[id name description upstreams] }

  it { is_expected.to require_graphql_authorizations(:read_virtual_registry) }
  it { is_expected.to have_graphql_fields(fields) }

  describe 'upstream registries' do
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

    context 'with the maven virtual registry feature flag turned on' do
      it 'returns upstreams registries' do
        maven_registries = query_result.dig(*%w[data group mavenVirtualRegistries nodes])
        upstreams = maven_registries[0]['upstreams']

        expect(upstreams.length).to be 1
        expect(upstreams[0]["name"]).to eq upstream.name
      end
    end
  end
end
