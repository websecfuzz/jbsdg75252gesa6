# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DastScannerProfile, :dynamic_analysis, feature_category: :dynamic_application_security_testing, type: :model do
  subject { create(:dast_scanner_profile) }

  it_behaves_like 'sanitizable', :dast_scanner_profile, %i[name]
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'scopes' do
    describe '.project_id_in' do
      it 'returns the dast_scanner_profiles for given projects' do
        result = described_class.project_id_in([subject.project.id])
        expect(result).to eq([subject])
      end
    end

    describe '.with_name' do
      it 'returns the dast_scanner_profiles with given name' do
        result = described_class.with_name(subject.name)
        expect(result).to eq([subject])
      end
    end
  end

  describe '.names' do
    it 'returns the names for the DAST scanner profiles with the given IDs' do
      first_profile = create(:dast_scanner_profile, name: 'First profile')
      second_profile = create(:dast_scanner_profile, name: 'Second profile')

      names = described_class.names([first_profile.id, second_profile.id])

      expect(names).to contain_exactly('First profile', 'Second profile')
    end

    context 'when a profile is not found' do
      it 'rescues the error and returns an empty array' do
        names = described_class.names([0])

        expect(names).to be_empty
      end
    end
  end

  describe '#ci_variables' do
    let(:target_type) { 'website' }
    let(:dast_site_profile) { build(:dast_site_profile, target_type: target_type) }
    let(:collection) { subject.ci_variables(dast_site_profile: dast_site_profile) }

    it 'returns a collection of variables' do
      expected_variables = [
        { key: 'DAST_DEBUG', value: 'false', public: true, masked: false },
        { key: 'DAST_FULL_SCAN_ENABLED', value: 'false', public: true, masked: false },
        { key: 'DAST_BROWSER_SCAN', value: 'true', public: true, masked: false }
      ]

      expect(collection.to_runner_variables).to eq(expected_variables)
    end

    context 'when optional fields are set' do
      subject { build(:dast_scanner_profile, spider_timeout: 1, target_timeout: 2) }

      it 'returns a collection of variables including these', :aggregate_failures do
        expect(collection).to include(key: 'DAST_TARGET_AVAILABILITY_TIMEOUT', value: String(subject.target_timeout), public: true)
        expect(collection).to include(key: 'DAST_BROWSER_CRAWL_TIMEOUT', value: "#{String(subject.spider_timeout)}m", public: true)
      end
    end

    context 'when the scan_type is active' do
      let(:collection) { subject.ci_variables(dast_site_profile: dast_site_profile) }

      subject { build(:dast_scanner_profile, scan_type: :active) }

      it 'returns a collection of variables with the passive profile', :aggregate_failures do
        expect(collection).to include(key: 'DAST_FULL_SCAN_ENABLED', value: 'true')
      end
    end

    context 'when the target_type is api' do
      let(:target_type) { 'api' }
      let(:collection) { subject.ci_variables(dast_site_profile: dast_site_profile) }

      context 'when the scan_type is active' do
        subject { build(:dast_scanner_profile, scan_type: :active) }

        it 'returns a collection of variables with the passive profile', :aggregate_failures do
          expect(collection).to include(key: 'DAST_API_PROFILE', value: 'Active-Quick')
        end
      end

      context 'when the scan_type is passive' do
        subject { build(:dast_scanner_profile, scan_type: :passive) }

        it 'returns a collection of variables with the passive profile', :aggregate_failures do
          expect(collection).to include(key: 'DAST_API_PROFILE', value: 'Quick')
        end
      end
    end
  end

  describe '#referenced_in_security_policies' do
    context 'there is no security_orchestration_policy_configuration assigned to project' do
      it 'returns the referenced policy name' do
        expect(subject.referenced_in_security_policies).to eq([])
      end
    end

    context 'there is security_orchestration_policy_configuration assigned to project' do
      let(:group_security_policy_configuration) { instance_double(Security::OrchestrationPolicyConfiguration, present?: true, active_policy_names_with_dast_scanner_profile: Set.new) }
      let(:security_orchestration_policy_configuration) { instance_double(Security::OrchestrationPolicyConfiguration, present?: true, active_policy_names_with_dast_scanner_profile: ['Policy Name'].to_set) }

      before do
        allow(subject.project).to receive(:security_orchestration_policy_configuration).and_return(security_orchestration_policy_configuration)
        allow(subject.project).to receive(:all_security_orchestration_policy_configurations).and_return([group_security_policy_configuration, security_orchestration_policy_configuration])
      end

      it 'calls security_orchestration_policy_configuration.active_policy_names_with_dast_scanner_profile with profile name' do
        expect(group_security_policy_configuration).to receive(:active_policy_names_with_dast_scanner_profile).with(subject.name)
        expect(security_orchestration_policy_configuration).to receive(:active_policy_names_with_dast_scanner_profile).with(subject.name)

        subject.referenced_in_security_policies
      end

      it 'returns empty array' do
        expect(subject.referenced_in_security_policies).to eq(['Policy Name'])
      end
    end
  end

  describe '#can_edit_profile?' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:dast_profile) { create(:dast_profile, project: project, branch_name: 'master') }

    subject { DastScannerProfilesFinder.new(id: dast_profile.dast_scanner_profile_id).execute.to_a.first }

    where(:can_push_to_branch, :result) do
      false | false
      true  | true
    end

    with_them do
      it do
        expect_next_instance_of(Gitlab::UserAccess) do |instance|
          expect(instance).to receive(:can_push_to_branch?).with('master').and_return(can_push_to_branch)
        end

        expect(subject.can_edit_profile?(user)).to eq(result)
      end
    end
  end

  describe '#can_edit_profile? avoids N+1 queries' do
    it do
      project = create(:project, :repository)
      user = create(:user, maintainer_of: project)
      dast_profile1 = create(:dast_profile, project: project, branch_name: 'master')
      dast_scanner_profile1 = dast_profile1.dast_scanner_profile

      control = ActiveRecord::QueryRecorder.new { dast_scanner_profile1.can_edit_profile?(user) }

      create(:dast_profile, project: project, branch_name: 'master', dast_scanner_profile: dast_scanner_profile1)

      expect { dast_scanner_profile1.can_edit_profile?(user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with loose foreign key on dast_scanner_profiles.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:dast_scanner_profile, project: parent) }
    end
  end
end
