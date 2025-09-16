# frozen_string_literal: true

RSpec.shared_examples 'read_duo_usage_analytics permissions' do
  using RSpec::Parameterized::TableSyntax

  where(:role, :has_subscription_assignment, :feature_flag_enabled, :allowed) do
    :guest    | false | false | false
    :guest    | false | true | false
    :guest    | true  | false | false
    :guest    | true  | true | false
    :reporter | false | false | false
    :reporter | false | true | false
    :reporter | true | false | false
    :reporter | true | true | true
  end

  with_them do
    let(:current_user) { public_send(role) }

    before do
      stub_feature_flags(duo_usage_dashboard: feature_flag_enabled)

      if has_subscription_assignment
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: current_user,
          add_on_purchase: subscription_purchase
        )
      end
    end

    it { is_expected.to(allowed ? be_allowed(:read_duo_usage_analytics) : be_disallowed(:read_duo_usage_analytics)) }
  end
end
