# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/hooks/index', feature_category: :webhooks do
  let(:existing_hook) { create(:project_hook, project: project) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- can't use build/build_stubbed.
  let(:new_hook) { ProjectHook.new }

  let_it_be_with_refind(:project) { create(:project) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- can't use build/build_stubbed.

  before do
    assign :project, project
    assign :hooks, [existing_hook]
    assign :hook, new_hook
  end

  it "renders the 'Vulnerability events' checkbox" do
    render

    expect(rendered).to have_text('Vulnerability events')
  end
end
