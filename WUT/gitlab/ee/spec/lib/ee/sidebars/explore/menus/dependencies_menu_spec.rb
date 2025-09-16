# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::Sidebars::Explore::Menus::DependenciesMenu, feature_category: :dependency_management do
  subject(:menu) { described_class.new(context) }

  let(:organization) { build(:organization) }
  let(:context) do
    Sidebars::Context.new(current_user: current_user, container: nil, current_organization: organization)
  end

  let(:current_user) { nil }

  describe "#link" do
    it "renders the correct link" do
      expect(menu.link).to match("explore/dependencies")
    end
  end

  describe "#title" do
    it "renders the correct title" do
      expect(menu.title).to eq("Dependency list")
    end
  end

  describe "#sprite_icon" do
    it "renders the correct icon" do
      expect(menu.sprite_icon).to eq("shield")
    end
  end

  describe "#render?" do
    context "when dependency scanning is available" do
      before do
        stub_licensed_features(dependency_scanning: true)
      end

      context "when a user is logged in" do
        let(:current_user) { build(:user) }

        context "when the user is an admin", :enable_admin_mode do
          let(:current_user) { create(:user, :admin) }

          context "when the user belongs to the organization" do
            it { is_expected.to be_render }
          end

          context "when the user does not belong to the organization" do
            let(:other_organization) { build(:organization) }
            let(:current_user) { create(:user, :admin, organizations: [other_organization]) }

            it { is_expected.to be_render }
          end

          context "when the feature flag is disabled" do
            before do
              stub_feature_flags(explore_dependencies: false)
            end

            it { is_expected.not_to be_render }
          end
        end

        context "when the user is not an admin" do
          it { is_expected.not_to be_render }
        end
      end

      context "when a user is not logged in" do
        let(:current_user) { nil }

        it { is_expected.not_to be_render }
      end
    end

    context "when dependency scanning is not available" do
      before do
        stub_licensed_features(dependency_scanning: true)
      end

      it { is_expected.not_to be_render }
    end
  end
end
