# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::GitlabDuoController, type: :request, feature_category: :ai_abstraction_layer do
  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }

  subject(:get_page) { get group_settings_gitlab_duo_path(group) }

  before do
    stub_licensed_features(code_suggestions: true)
    add_on = create(:gitlab_subscription_add_on)
    create(:gitlab_subscription_add_on_purchase, quantity: 50, namespace: group, add_on: add_on)
    sign_in(user)
  end

  context 'when user has read_usage_quotas permission' do
    let(:user) { owner }

    context "when show_gitlab_duo_settings_app? returns false" do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it "renders 404" do
        get_page

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context "when show_gitlab_duo_settings_app? returns true" do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it "renders show with 200 status code" do
        get_page

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end

    context 'when in a subgroup' do
      let(:subgroup) { create(:group, :private, parent: group) }

      before do
        subgroup.add_owner(user)
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it "renders 404" do
        get group_settings_gitlab_duo_path(subgroup)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  context 'when user does not have read_usage_quotas permission' do
    let(:user) { maintainer }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it "renders 404" do
      get_page

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end
