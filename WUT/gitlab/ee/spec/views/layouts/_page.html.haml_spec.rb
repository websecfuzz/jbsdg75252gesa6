# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/_page', feature_category: :global_search do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:project_namespace) { build_stubbed(:project_namespace) }
  let_it_be(:project) { build_stubbed(:project, project_namespace: project_namespace) }

  describe 'EE tanuki_bot_chat' do
    before do
      assign(:project, project)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:current_user_mode).and_return(Gitlab::Auth::CurrentUserMode.new(user))
    end

    describe 'when project is nil' do
      let_it_be(:project) { nil }

      it 'does not render #js-tanuki-bot-chat-app' do
        render

        expect(rendered).not_to have_selector('#js-tanuki-bot-chat-app')
      end
    end

    describe 'when ::Gitlab::Llm::TanukiBot.enabled_for?(user) is true' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:enabled_for?)
          .with(user: user, container: nil).and_return(true)
      end

      it 'renders #js-tanuki-bot-chat-app' do
        render

        expect(rendered).to have_selector('#js-tanuki-bot-chat-app')
      end
    end

    describe 'when ::Gitlab::Llm::TanukiBot.enabled_for?(user) is false' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:enabled_for?)
          .with(user: user, container: nil).and_return(false)
      end

      it 'does not render #js-tanuki-bot-chat-app' do
        render

        expect(rendered).not_to have_selector('#js-tanuki-bot-chat-app')
      end
    end
  end
end
