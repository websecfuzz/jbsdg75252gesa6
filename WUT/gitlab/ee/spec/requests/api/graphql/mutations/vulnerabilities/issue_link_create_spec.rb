# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mutation.vulnerabilityIssueLinkCreate", feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project) }

  let(:arguments) do
    {
      issue_id: issue.to_global_id.to_s,
      vulnerability_ids: [vulnerability.to_global_id.to_s]
    }
  end

  subject(:mutation) { graphql_mutation(:vulnerability_issue_link_create, arguments) }

  context "with a custom role" do
    let!(:membership) { create(:project_member, :guest, user: current_user, source: project, member_role: role) }

    before do
      stub_licensed_features(security_dashboard: true, custom_roles: true)
    end

    context "with `admin_vulnerability` enabled" do
      let(:role) { create(:member_role, :guest, :admin_vulnerability, namespace: project.group) }

      it "returns a successful response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        mutation_response = graphql_mutation_response(:vulnerability_issue_link_create)
        expect(mutation_response["issueLinks"]).to be_present
        expect(mutation_response["errors"]).to be_empty
      end
    end

    context "with `admin_vulnerability` disabled" do
      let(:role) { nil }

      it "returns an empty response" do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_mutation_response(:vulnerability_issue_link_create)).to be_nil
      end
    end
  end
end
