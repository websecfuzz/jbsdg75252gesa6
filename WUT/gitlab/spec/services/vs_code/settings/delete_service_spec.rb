# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VsCode::Settings::DeleteService, feature_category: :web_ide do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:other_user) { create(:user) }
    let_it_be(:setting_one) { create(:vscode_setting, user: user) }
    let_it_be(:setting_two) do
      create(:vscode_setting, setting_type: 'extensions', settings_context_hash: '1234', user: user)
    end

    let_it_be(:setting_three) do
      create(:vscode_setting, setting_type: 'extensions', settings_context_hash: '5678', user: other_user)
    end

    subject { described_class.new(current_user: user).execute }

    it 'deletes all vscode_settings belonging to the current user' do
      expect { subject }
        .to change { User.find(user.id).vscode_settings.count }.from(2).to(0)
        .and not_change { User.find(other_user.id).vscode_settings.count }
    end
  end
end
