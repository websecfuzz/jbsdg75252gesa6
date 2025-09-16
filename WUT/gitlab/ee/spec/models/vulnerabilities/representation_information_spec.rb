# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::RepresentationInformation, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:vulnerability) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:vulnerability) }
    it { is_expected.to validate_presence_of(:project) }
  end

  describe 'SHA attribute fields' do
    subject(:sha_attribute_fields) { described_class.sha_attribute_fields }

    it 'includes the resolved_in_commit_sha attribute' do
      is_expected.to contain_exactly(:resolved_in_commit_sha)
    end
  end

  context 'with loose foreign key on vulnerability_feedback.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) do
        create(:vulnerability_representation_information, vulnerability: create(:vulnerability, project: parent))
      end
    end
  end
end
