# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::SeverityOverride, feature_category: :vulnerability_management do
  it { is_expected.to define_enum_for(:new_severity) }
  it { is_expected.to define_enum_for(:original_severity) }

  describe 'associations' do
    it { is_expected.to belong_to(:author).class_name('User').inverse_of(:vulnerability_severity_overrides) }
    it { is_expected.to belong_to(:vulnerability).class_name('Vulnerability').inverse_of(:severity_overrides) }
    it { is_expected.to belong_to(:project).required(true) }
  end

  describe 'validations' do
    let_it_be(:severity_override) { create(:vulnerability_severity_override, new_severity: :high) }

    it { is_expected.to validate_presence_of(:vulnerability) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:original_severity) }
    it { is_expected.to validate_presence_of(:new_severity) }
    it { is_expected.to validate_presence_of(:author).on(:create) }

    it "is expected to validate that original and new severities differ" do
      severity_override.original_severity = severity_override.new_severity

      expect(severity_override).to be_invalid
      expect { severity_override.save! }.to raise_error(ActiveRecord::RecordInvalid,
        'Validation failed: New severity must not be the same as original severity')
    end

    context 'when attribute values are valid' do
      let_it_be(:project) { create(:project) }
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let_it_be(:user) { create(:user) }
      let_it_be(:severity_overrides) do
        [
          build(:vulnerability_severity_override,
            vulnerability: vulnerability,
            project: project,
            author: user,
            original_severity: :low,
            new_severity: :critical
          )
        ]
      end

      subject { build(:vulnerability, severity_overrides: severity_overrides) }

      it { is_expected.to be_valid }
    end
  end

  context 'with loose foreign key on vulnerability_severity_overrides.author_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:user) }
      let_it_be(:model) { create(:vulnerability_severity_override, author: parent) }
    end
  end

  context 'with loose foreign key on vulnerability_severity_overrides.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerability_severity_override, project_id: parent.id) }
    end
  end

  describe '#author_data' do
    let_it_be(:user) { create(:user, name: 'Test User') }
    let_it_be(:project) { create(:project) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project) }

    context 'when author exists' do
      let(:author) { user }
      let(:expected_author_data) do
        {
          author: {
            name: user.name,
            web_url: Gitlab::Routing.url_helpers.user_path(username: user.username)
          }
        }
      end

      subject(:severity_override) do
        create(:vulnerability_severity_override,
          vulnerability: vulnerability,
          project: project,
          author: author,
          original_severity: :low,
          new_severity: :critical
        )
      end

      it 'returns author data hash with name and web_url' do
        expect(severity_override.author_data).to eq(expected_author_data)
      end
    end

    context 'when author does not exist' do
      subject(:severity_override) do
        build(:vulnerability_severity_override,
          vulnerability: vulnerability,
          project: project,
          author: nil,
          original_severity: :low,
          new_severity: :critical
        )
      end

      it 'returns nil' do
        expect(severity_override.author_data).to be_nil
      end
    end
  end

  describe '.latest' do
    let_it_be(:project) { create(:project) }
    let_it_be(:vulnerability1) { create(:vulnerability, project: project) }
    let_it_be(:vulnerability2) { create(:vulnerability, project: project) }
    let_it_be(:old_override1) do
      create(:vulnerability_severity_override,
        vulnerability: vulnerability1,
        project: project,
        original_severity: :low,
        new_severity: :medium,
        created_at: 2.days.ago
      )
    end

    let_it_be(:new_override1) do
      create(:vulnerability_severity_override,
        vulnerability: vulnerability1,
        project: project,
        original_severity: :medium,
        new_severity: :high,
        created_at: 1.day.ago
      )
    end

    let_it_be(:old_override2) do
      create(:vulnerability_severity_override,
        vulnerability: vulnerability2,
        project: project,
        original_severity: :low,
        new_severity: :medium,
        created_at: 2.days.ago
      )
    end

    let_it_be(:new_override2) do
      create(:vulnerability_severity_override,
        vulnerability: vulnerability2,
        project: project,
        original_severity: :medium,
        new_severity: :high,
        created_at: 1.day.ago
      )
    end

    it 'returns only the latest override for each vulnerability' do
      expect(described_class.latest).to contain_exactly(new_override1, new_override2)
    end
  end
end
