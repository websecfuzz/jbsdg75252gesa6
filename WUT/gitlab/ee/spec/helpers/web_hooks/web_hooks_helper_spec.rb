# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WebHooks::WebHooksHelper, :clean_gitlab_redis_shared_state, feature_category: :webhooks do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }

  let(:current_user) { nil }
  let(:callout_dismissed) { false }
  let(:viewing_hooks) { true }
  let(:a_hook_has_failed) { false }

  before do
    allow(helper).to receive(:current_user).and_return(current_user)
    allow(helper).to receive(:web_hook_disabled_dismissed?).with(group).and_return(callout_dismissed)
    allow(helper).to receive(:current_controller?).with('groups/hooks').and_return(viewing_hooks)
    allow(helper).to receive(:current_controller?).with('groups/hook_logs').and_return(viewing_hooks)
    allow(group).to receive(:any_hook_failed?).and_return(a_hook_has_failed)
  end

  shared_context 'when we are not viewing the group hooks or the logs' do
    let(:viewing_hooks) { false }
  end

  shared_context 'when the user has permission' do
    before do
      allow(Ability).to receive(:allowed?).with(user, :admin_web_hook, group).and_return(true)
    end
  end

  shared_context 'when a user is logged in' do
    let(:current_user) { user }
  end

  shared_context 'when the user dismissed the callout' do
    let(:callout_dismissed) { true }
  end

  shared_context 'when a hook has failed' do
    let(:a_hook_has_failed) { true }
  end

  describe '#show_group_hook_failed_callout?' do
    context 'when all conditions are met' do
      include_context 'when a user is logged in'
      include_context 'when the user has permission'
      include_context 'when we are not viewing the group hooks or the logs'
      include_context 'when a hook has failed'

      it 'is true' do
        expect(helper.show_group_hook_failed_callout?(group: group)).to eq(true)
      end
    end

    context 'when any one condition is not met' do
      contexts = [
        'when a user is logged in',
        'when the user has permission',
        'when we are not viewing the group hooks or the logs',
        'when a hook has failed'
      ]

      contexts.each do |name|
        context "namely #{name}" do
          contexts.each { |ctx| include_context(ctx) unless ctx == name }

          it 'is false' do
            expect(helper.show_group_hook_failed_callout?(group: group)).to eq(false)
          end
        end
      end
    end
  end
end
