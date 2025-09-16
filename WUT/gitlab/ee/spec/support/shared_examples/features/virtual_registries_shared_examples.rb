# frozen_string_literal: true

RSpec.shared_examples 'virtual registry is unavailable' do
  context 'when dependency proxy feature is not available' do
    before do
      stub_config(dependency_proxy: { enabled: false })
    end

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when license is invalid' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
    end

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end

  context 'when group is not root group' do
    let(:group) { create(:group, :private, parent: super()) }

    it 'renders 404' do
      visit url

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end
end
