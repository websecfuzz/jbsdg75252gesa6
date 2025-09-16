# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::MergeRequestLink, feature_category: :vulnerability_management do
  describe 'associations and fields' do
    it { is_expected.to belong_to(:vulnerability) }
    it { is_expected.to belong_to(:merge_request) }
    it { is_expected.to have_one(:author).through(:merge_request).class_name("User") }
  end

  context 'with loose foreign key on vulnerability_merge_request_links.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilities_merge_request_link, project_id: parent.id) }
    end
  end

  context 'with loose foreign key on vulnerability_merge_request_links.merge_request_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:merge_request) }
      let_it_be(:model) { create(:vulnerabilities_merge_request_link, merge_request: parent) }
    end
  end
end
