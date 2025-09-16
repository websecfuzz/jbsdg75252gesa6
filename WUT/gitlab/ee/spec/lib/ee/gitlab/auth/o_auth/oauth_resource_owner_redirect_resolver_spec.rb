# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::OAuth::OauthResourceOwnerRedirectResolver, feature_category: :system_access do
  let(:resolver) { described_class.new(namespace_id) }
  let(:namespace_id) { nil }
  let(:saml_provider) { create(:saml_provider, enforced_sso: true) }
  let(:group) { saml_provider.group }
  let(:child_group) { create(:group, parent: group) }

  before do
    allow(Gitlab).to receive(:ee?).and_return(true)
    allow(resolver).to receive(:new_user_session_url).and_return('/login')
  end

  describe '#resolve_redirect_url' do
    subject(:resolve_redirect_url) { resolver.resolve_redirect_url }

    context 'when root_namespace_id is blank' do
      let(:namespace_id) { nil }

      it 'returns new_user_session_url' do
        expect(resolve_redirect_url).to eq('/login')
      end

      it 'does not query for group' do
        expect(::Group).not_to receive(:find_by_id)
        resolve_redirect_url
      end
    end

    context 'when namespace is found' do
      let(:namespace_id) { group.id }

      context 'when found namespace is a Group' do
        context 'when feature flag is enabled' do
          context 'when SSO URL is present' do
            let(:sso_url) { "/groups/#{group.full_path}/-/saml/sso" }

            before do
              allow(resolver).to receive(:build_sso_redirect_url)
                .with(group)
                .and_return(sso_url)
            end

            it 'returns the SSO URL' do
              expect(resolver).to receive(:build_sso_redirect_url).with(group)
              expect(resolve_redirect_url).to eq(sso_url)
            end
          end

          context 'when SSO URL is nil' do
            before do
              allow(resolver).to receive(:build_sso_redirect_url)
                .with(group)
                .and_return(nil)
            end

            it 'returns new_user_session_url' do
              expect(resolve_redirect_url).to eq('/login')
            end
          end

          context 'when SSO URL is empty string' do
            before do
              allow(resolver).to receive(:build_sso_redirect_url)
                .with(group)
                .and_return('')
            end

            it 'returns new_user_session_url' do
              expect(resolve_redirect_url).to eq('/login')
            end
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(ff_oauth_redirect_to_sso_login: false)
          end

          it 'returns new_user_session_url' do
            expect(resolver).not_to receive(:build_sso_redirect_url)
            expect(resolve_redirect_url).to eq('/login')
          end
        end
      end

      context 'when found namespace is not a Group' do
        let(:user_namespace) { create(:user_namespace) }
        let(:namespace_id) { user_namespace.id }

        it 'returns new_user_session_url' do
          expect(resolve_redirect_url).to eq('/login')
        end
      end
    end

    context 'when namespace is not found' do
      let(:namespace_id) { 999999 }

      it 'returns new_user_session_url' do
        expect(resolve_redirect_url).to eq('/login')
      end
    end

    context 'with child namespace path' do
      let(:namespace_id) { child_group.id }

      before do
        allow(resolver).to receive(:build_sso_redirect_url)
          .with(child_group)
          .and_return('/sso-url')
      end

      it 'works with nested groups' do
        expect(resolve_redirect_url).to eq('/sso-url')
      end
    end
  end

  describe '#build_sso_redirect_url' do
    subject(:build_sso_redirect_url) { resolver.send(:build_sso_redirect_url, group) }

    let(:sso_redirector) { instance_double(::RoutableActions::SsoEnforcementRedirect) }
    let(:expected_url) { "/groups/#{group.full_path}/-/saml/sso" }

    before do
      allow(::RoutableActions::SsoEnforcementRedirect)
        .to receive(:new)
        .with(group, group.full_path)
        .and_return(sso_redirector)

      allow(group).to receive(:enforced_sso?).and_return(true)
    end

    context 'when redirector returns SSO url' do
      before do
        allow(sso_redirector).to receive(:sso_redirect_url).and_return(expected_url)
      end

      it 'returns the SSO redirect URL' do
        expect(build_sso_redirect_url).to eq(expected_url)
      end
    end

    context 'when redirector returns nil' do
      before do
        allow(sso_redirector).to receive(:sso_redirect_url).and_return(nil)
      end

      it 'returns nil' do
        expect(build_sso_redirect_url).to be_nil
      end
    end

    context 'when group does not have enforced SSO' do
      before do
        allow(group).to receive(:enforced_sso?).and_return(false)
      end

      it 'returns nil' do
        expect(build_sso_redirect_url).to be_nil
      end
    end
  end
end
