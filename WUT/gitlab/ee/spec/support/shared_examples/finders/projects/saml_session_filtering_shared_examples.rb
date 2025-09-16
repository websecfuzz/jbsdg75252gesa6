# frozen_string_literal: true

RSpec.shared_examples 'projects finder with SAML session filtering' do
  let(:params) { { filter_expired_saml_session_projects: true } }

  let_it_be(:current_user) { user }

  let_it_be(:saml_provider1) { create(:saml_provider, enabled: true, enforced_sso: true) }
  let_it_be(:saml_provider2) { create(:saml_provider, enabled: true, enforced_sso: true) }
  let_it_be(:saml_provider3) { create(:saml_provider, enabled: true, enforced_sso: true) }

  let_it_be(:root_group1) do
    create(:group, saml_provider: saml_provider1, developers: current_user) do |group|
      create(:group_saml_identity, saml_provider: group.saml_provider, user: current_user)
    end
  end

  let_it_be(:root_group2) do
    create(:group, saml_provider: saml_provider2)
  end

  let_it_be(:private_root_group) do
    create(:group, :private, saml_provider: saml_provider3, developers: current_user) do |group|
      create(:group_saml_identity, saml_provider: group.saml_provider, user: current_user)
    end
  end

  let_it_be(:project1) { create(:project, :public, group: root_group1) }
  let_it_be(:project2) { create(:project, :public, group: root_group2) }
  let_it_be(:private_project) { create(:project, :private, group: private_root_group) }
  let_it_be(:all_projects) { [project1, project2, private_project] }

  before do
    stub_licensed_features(group_saml: true)
  end

  subject(:projects) { finder.execute.id_in(all_projects).to_a }

  context 'when the current user is nil' do
    let_it_be(:current_user) { nil }

    it 'includes public SAML projects' do
      expect(projects).to contain_exactly(project1, project2)
    end
  end

  shared_examples 'includes all SAML projects' do
    specify do
      expect(projects).to match_array(all_projects)
    end
  end

  context 'when the current user is an admin', :enable_admin_mode do
    let_it_be(:current_user) { create(:admin) }

    it_behaves_like 'includes all SAML projects'
  end

  context 'when the current user has no active SAML sessions' do
    context 'when in the context of web activity' do
      around do |example|
        session = { 'warden.user.user.key' => [[current_user.id], current_user.authenticatable_salt] }
        Gitlab::Session.with_session(session) do
          example.run
        end
      end

      it 'filters out the SAML member projects' do
        expect(projects).to contain_exactly(project2)
      end
    end

    context 'when not in the context of web activity' do
      it_behaves_like 'includes all SAML projects'
    end
  end

  context 'when filter_expired_saml_session_projects param is false' do
    let(:params) { { filter_expired_saml_session_projects: false } }

    it_behaves_like 'includes all SAML projects'
  end

  context 'when the current user has active SAML sessions' do
    before do
      active_saml_sessions = { root_group1.saml_provider.id => Time.current,
                               private_root_group.saml_provider.id => Time.current }
      allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
    end

    it_behaves_like 'includes all SAML projects'
  end
end
