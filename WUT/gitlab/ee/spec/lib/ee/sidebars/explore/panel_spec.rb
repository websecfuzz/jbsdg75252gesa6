# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Explore::Panel, feature_category: :navigation do
  subject { described_class.new(context) }

  let(:context) { Sidebars::Context.new(current_user: current_user, container: nil) }
  let(:current_user) { build_stubbed(:user) }

  describe '#configure_menus' do
    it { is_expected.to include_menu(::EE::Sidebars::Explore::Menus::DependenciesMenu) }
  end
end
