# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabDuoController, :cloud_licenses, feature_category: :ai_abstraction_layer do
  include AdminModeHelper

  describe 'GET /admin/gitlab_duo', :with_cloud_connector do
    let(:plan) { License::STARTER_PLAN }
    let(:license) { build(:license, plan: plan) }

    before do
      allow(License).to receive(:current).and_return(license)
      allow(::Gitlab::Saas).to receive(:feature_available?).and_return(false)
    end

    shared_examples 'renders the activation form' do
      it 'renders the activation form and skips completion test' do
        get admin_gitlab_duo_path

        expect(response).to render_template(:show)
        expect(response.body).to include('js-gitlab-duo-admin-page')
        expect(flash.now[:notice]).to be_nil
        expect(flash.now[:alert]).to be_nil
      end

      context 'when duo pro addon is purchased' do
        let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_pro, :active) }

        it 'renders the activation form' do
          get admin_gitlab_duo_path

          expect(response).to render_template(:show)
          expect(response.body).to include('js-gitlab-duo-admin-page')
        end
      end
    end

    shared_examples 'hides gitlab duo path' do
      it 'returns 404' do
        get admin_gitlab_duo_path

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response).to render_template('errors/not_found')
      end
    end

    context 'when the user is not admin' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it_behaves_like 'hides gitlab duo path'
    end

    context 'when the user is an admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        login_as(admin)
        enable_admin_mode!(admin)
      end

      context 'when instance is not on GitLab.com' do
        before do
          allow(Gitlab).to receive(:com?).and_return(false)
        end

        context 'when the license is paid' do
          before do
            allow(License).to receive(:current).and_return(build(:license, plan: License::PREMIUM_PLAN))
          end

          it_behaves_like 'renders the activation form'
        end

        context 'when the instance has a non-paid license' do
          before do
            allow(License).to receive(:current).and_return(build(:license, plan: License::LEGACY_LICENSE_TYPE))
          end

          it_behaves_like 'hides gitlab duo path'
        end

        context 'when the instance does not have a license' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it_behaves_like 'hides gitlab duo path'
        end
      end

      context 'when instance is on GitLab.com' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        context 'when the license is paid' do
          before do
            allow(License).to receive(:current).and_return(build(:license, plan: License::PREMIUM_PLAN))
          end

          it_behaves_like 'renders the activation form'
        end

        context 'when the instance has a non-paid license' do
          before do
            allow(License).to receive(:current).and_return(build(:license, plan: License::LEGACY_LICENSE_TYPE))
          end

          it_behaves_like 'hides gitlab duo path'
        end

        context 'when the instance does not have a license' do
          before do
            allow(License).to receive(:current).and_return(nil)
          end

          it_behaves_like 'hides gitlab duo path'
        end
      end
    end
  end
end
