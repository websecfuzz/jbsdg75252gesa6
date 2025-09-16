# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_permissions.html.haml', :aggregate_failures, :saas, feature_category: :code_suggestions do
  let_it_be(:group) { build(:group, namespace_settings: build(:namespace_settings)) }

  before do
    assign(:group, group)
    allow(view).to receive(:can?).and_return(true)
    allow(view).to receive(:current_user).and_return(build(:user))
  end

  context 'for auto assign duo pro seats' do
    context 'when on SM' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'renders nothing' do
        render

        expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
        expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
      end
    end

    context 'when on .com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(auto_assign_gitlab_duo_pro_seats: false)
        end

        it 'renders nothing' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end

      context 'when group is not a root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'renders nothing' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end

      context 'when group does not have the add-on purchased' do
        it 'renders nothing' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end

      context 'when all conditions are met' do
        before do
          allow(group).to receive(:code_suggestions_purchased?).and_return(true)
        end

        it 'renders the option' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end
    end
  end

  context 'for extended token expiry webhook execution setting' do
    let_it_be(:checkbox_label) { s_('GroupSettings|Add additional webhook triggers for group access token expiration') }

    before do
      allow(group).to receive(:licensed_feature_available?).and_return(true)
    end

    context 'when `group_webhooks` licensed feature is not available' do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:group_webhooks).and_return(false)
      end

      it 'renders nothing', :aggregate_failures do
        render

        expect(rendered).to render_template('groups/settings/_extended_grat_expiry_webhook_execute')
        expect(rendered).not_to have_content(
          s_('GroupSettings|Add additional webhook triggers for group access token expiration')
        )
      end
    end

    context 'when `group_webhooks` licensed feature is available' do
      before do
        allow(group).to receive(:licensed_feature_available?).with(:group_webhooks).and_return(true)
      end

      it 'renders checkbox', :aggregate_failures do
        render

        expect(rendered).to render_template('groups/settings/_extended_grat_expiry_webhook_execute')
        expect(rendered).to have_content(
          s_('GroupSettings|Add additional webhook triggers for group access token expiration')
        )
        expect(rendered).to have_unchecked_field(checkbox_label, type: 'checkbox')
      end
    end
  end

  context 'for extensions marketplace settings' do
    let_it_be(:section_title) { _('Web IDE and workspaces') }
    let_it_be(:checkbox_label) { s_('GroupSettings|Enable extension marketplace') }

    context 'when cannot manage extensions marketplace for enterprise users' do
      it 'renders nothing', :aggregate_failures do
        allow(group).to receive(:can_manage_extensions_marketplace_for_enterprise_users?).and_return(false)

        render

        expect(rendered).to render_template('groups/settings/_extensions_marketplace')
        expect(rendered).not_to have_content(section_title)
        expect(rendered).not_to have_field(checkbox_label, type: 'checkbox')
      end
    end

    context 'when can manage extensions marketplace for enterprise users' do
      it 'renders checkbox', :aggregate_failures do
        allow(group).to receive(:can_manage_extensions_marketplace_for_enterprise_users?).and_return(true)

        render

        expect(rendered).to render_template('groups/settings/_extensions_marketplace')
        expect(rendered).to have_content(section_title)
        expect(rendered).to have_unchecked_field(checkbox_label, type: 'checkbox')
      end
    end
  end
end
