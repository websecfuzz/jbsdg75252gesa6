# frozen_string_literal: true

require 'spec_helper'
RSpec.describe 'admin/gitlab_duo/show.html.haml', feature_category: :shared do
  before do
    allow(view).to receive(:current_user).and_return(build_stubbed(:admin))
  end

  describe 'with enabled duo banner' do
    it 'renders the partial' do
      render

      expect(rendered).to render_template(
        partial: 'admin/enable_duo_banner_sm',
        locals: {
          title: s_('AiPowered|Get started with GitLab Duo Core'),
          callouts_feature_name: 'enable_duo_banner_admin_duo_settings_page'
        }
      )
    end
  end
end
