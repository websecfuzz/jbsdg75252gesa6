# frozen_string_literal: true

RSpec.shared_context 'instance integration activation', :with_current_organization do
  include_context 'instance and group integration activation'

  let_it_be(:user) { create(:user, :admin) }

  before do
    sign_in(user)
    enable_admin_mode!(user)
  end

  def visit_instance_integrations
    visit integrations_admin_application_settings_path
  end

  def visit_instance_integration(name)
    visit_instance_integrations

    within('#content-body') do
      click_link(name, match: :prefer_exact)
    end
  end
end
