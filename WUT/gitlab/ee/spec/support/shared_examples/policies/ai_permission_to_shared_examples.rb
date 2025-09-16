# frozen_string_literal: true

RSpec.shared_examples 'ai permission to' do |ability|
  using RSpec::Parameterized::TableSyntax

  where(:role, :has_subscription_assignment, :allowed) do
    :guest    | false | false
    :guest    | true  | false
    :reporter | false | false
    :reporter | true  | true
  end

  with_them do
    let(:current_user) { public_send(role) }

    before do
      if has_subscription_assignment
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: current_user,
          add_on_purchase: subscription_purchase
        )
      end
    end

    it { is_expected.to(allowed ? be_allowed(ability) : be_disallowed(ability)) }
  end
end
