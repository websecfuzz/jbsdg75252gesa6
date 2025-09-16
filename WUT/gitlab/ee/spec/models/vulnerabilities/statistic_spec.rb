# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Statistic, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project).required(true) }
    it { is_expected.to belong_to(:pipeline).required(false) }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:total).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:critical).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:high).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:medium).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:low).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:unknown).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:info).is_greater_than_or_equal_to(0) }
    it { is_expected.to define_enum_for(:letter_grade).with_values(%i[a b c d f]) }
  end

  describe '.before_save' do
    describe '#assign_letter_grade' do
      let_it_be(:pipeline) { create(:ci_pipeline) }
      let_it_be(:project) { pipeline.project }

      let(:statistic) { build(:vulnerability_statistic, letter_grade: nil, critical: 5, project: project) }

      subject(:save_statistic) { statistic.save! }

      it 'assigns the letter_grade' do
        expect { save_statistic }.to change { statistic.letter_grade }.from(nil).to('f')
      end
    end
  end

  describe '.by_grade' do
    let!(:statistic_grade_a) { create(:vulnerability_statistic, letter_grade: :a) }

    subject { described_class.by_grade(:a) }

    before do
      %w[b c d f].each { create(:vulnerability_statistic, :"grade_#{_1}") }
    end

    it { is_expected.to match_array([statistic_grade_a]) }
  end

  describe '.by_group' do
    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_2) { create(:group) }
    let_it_be(:group_1_1) { create(:group, parent: group_1) }
    let_it_be(:project_1) { create(:project, group: group_1) }
    let_it_be(:project_1_1) { create(:project, group: group_1_1) }
    let_it_be(:project_2) { create(:project, group: group_2) }
    let_it_be(:vulnerability_statistic_1) { create(:vulnerability_statistic, project: project_1) }
    let_it_be(:vulnerability_statistic_1_1) { create(:vulnerability_statistic, project: project_1_1) }
    let_it_be(:vulnerability_statistic_2) { create(:vulnerability_statistic, project: project_2) }

    subject { described_class.by_group(group_1) }

    it 'returns all records within the group hierarchy' do
      is_expected.to contain_exactly(vulnerability_statistic_1, vulnerability_statistic_1_1)
    end
  end

  describe '.by_group_excluding_subgroups' do
    let_it_be(:group_1) { create(:group) }
    let_it_be(:group_2) { create(:group) }
    let_it_be(:group_1_1) { create(:group, parent: group_1) }
    let_it_be(:project_1) { create(:project, group: group_1) }
    let_it_be(:project_1_1) { create(:project, group: group_1_1) }
    let_it_be(:project_2) { create(:project, group: group_2) }
    let_it_be(:vulnerability_statistic_1) { create(:vulnerability_statistic, project: project_1) }
    let_it_be(:vulnerability_statistic_1_1) { create(:vulnerability_statistic, project: project_1_1) }
    let_it_be(:vulnerability_statistic_2) { create(:vulnerability_statistic, project: project_2) }

    subject { described_class.by_group_excluding_subgroups(group_1) }

    it 'returns all records within the group hierarchy' do
      is_expected.to contain_exactly(vulnerability_statistic_1)
    end
  end

  describe '.unarchived' do
    let_it_be(:active_project) { create(:project) }
    let_it_be(:archived_project) { create(:project, :archived) }
    let_it_be(:archived_vulnerability_statistic) { create(:vulnerability_statistic, project: archived_project) }
    let_it_be(:unarchived_vulnerability_statistic) { create(:vulnerability_statistic, project: active_project) }

    subject(:unarchived) { described_class.unarchived }

    it { is_expected.to contain_exactly(unarchived_vulnerability_statistic) }
  end

  describe '.letter_grade_for' do
    subject { described_class.letter_grade_for(object) }

    context 'when the given object is an instance of Vulnerabilities::Statistic' do
      let(:object) { build(:vulnerability_statistic, critical: 1) }

      it { is_expected.to eq(4) }
    end

    context 'when the given object is a Hash' do
      let(:object) { { 'high' => 1 } }

      it { is_expected.to eq(3) }
    end
  end

  describe '.letter_grade_sql_for' do
    using RSpec::Parameterized::TableSyntax

    where(:target_critical, :target_unknown, :target_high, :target_medium, :target_low, :excluded_critical, :excluded_unknown, :excluded_high, :excluded_medium, :excluded_low) do
      0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0

      0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1
      0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0
      0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1

      0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 1
      0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 1
      0 | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | 1

      0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 | 1 | 1
      0 | 0 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | 1
      0 | 0 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1

      0 | 0 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1
      0 | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1
      0 | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1

      0 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1
      1 | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 1 | 1
      1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1
    end

    with_them do
      let(:target) { "(#{target_critical}, #{target_unknown}, #{target_high}, #{target_medium}, #{target_low})" }
      let(:excluded) { "(#{excluded_critical}, #{excluded_unknown}, #{excluded_high}, #{excluded_medium}, #{excluded_low})" }
      let(:object) do
        {
          critical: target_critical + excluded_critical,
          uknown: target_unknown + excluded_unknown,
          high: target_high + excluded_high,
          medium: target_medium + excluded_medium,
          low: target_low + excluded_low
        }.stringify_keys
      end

      let(:letter_grade_sql) { described_class.letter_grade_sql_for(target, excluded) }
      let(:letter_grade_on_db) { described_class.connection.execute(letter_grade_sql).first['letter_grade'] }
      let(:letter_grade_on_app) { described_class.letter_grade_for(object) }

      it 'matches the application layer logic' do
        expect(letter_grade_on_db).to eq(letter_grade_on_app)
      end
    end
  end

  describe 'consistency between singular and bulk upsert' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let(:dynamic_attributes) { [:id, :created_at, :updated_at] }

    it 'sets the same fields with the same values in both methods' do
      described_class.set_latest_pipeline_with(pipeline)
      single_upsert_attributes = described_class.find_by(project_id: pipeline.project_id).attributes.except(dynamic_attributes)

      described_class.delete_all

      described_class.bulk_set_latest_pipelines_with([pipeline])
      bulk_record_attributes = described_class.find_by(project_id: pipeline.project_id).attributes.except(dynamic_attributes)

      expect(single_upsert_attributes.except('id')).to eq(bulk_record_attributes.except('id'))
    end
  end

  describe '.set_latest_pipeline_with' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be(:project) { pipeline.project }

    subject(:set_latest_pipeline) { described_class.set_latest_pipeline_with(pipeline) }

    context 'when there is already a vulnerability_statistic record available for the project of given pipeline' do
      let(:vulnerability_statistic) { create(:vulnerability_statistic, project: project) }

      it 'updates the `latest_pipeline_id` attribute of the existing record' do
        expect { set_latest_pipeline }.to change { vulnerability_statistic.reload.pipeline }.from(nil).to(pipeline)
      end
    end

    context 'when there is no vulnerability_statistic record available for the project of given pipeline' do
      before do
        project.update!(archived: true)
      end

      it 'creates a new record where latest_pipeline_id, archived, and traversal_ids are set' do
        expect { set_latest_pipeline }.to change { project.reload.vulnerability_statistic }.from(nil).to(an_instance_of(described_class))
                                      .and change { project.vulnerability_statistic&.pipeline }.from(nil).to(pipeline)
                                      .and change { project.vulnerability_statistic&.archived }.from(nil).to(project.archived)
                                      .and change { project.vulnerability_statistic&.traversal_ids }.from(nil).to(project.namespace.traversal_ids)
      end
    end
  end

  describe '.bulk_set_latest_pipelines_with' do
    let_it_be(:pipelines) { create_list(:ci_pipeline, 2) }
    let_it_be(:project_1) { pipelines.first.project }
    let_it_be(:project_2) { pipelines.second.project }

    subject(:bulk_set_latest_pipelines) { described_class.bulk_set_latest_pipelines_with(pipelines) }

    context 'when there is already a vulnerability_statistic record available for the project of given pipeline' do
      let(:vulnerability_statistic_1) { create(:vulnerability_statistic, project: project_1) }
      let(:vulnerability_statistic_2) { create(:vulnerability_statistic, project: project_2) }

      it 'updates the `latest_pipeline_id` attribute of the existing record' do
        expect { bulk_set_latest_pipelines }
          .to change { vulnerability_statistic_1.reload.pipeline }.from(nil).to(pipelines.first)
          .and change { vulnerability_statistic_2.reload.pipeline }.from(nil).to(pipelines.second)
      end
    end

    context 'when there is no vulnerability_statistic record available for the project of given pipeline' do
      it 'creates a new record with the `latest_pipeline_id` attribute is set' do
        expect { bulk_set_latest_pipelines }
          .to change { project_1.reload.vulnerability_statistic }.from(nil).to(an_instance_of(described_class))
          .and change { project_1.reload.vulnerability_statistic&.pipeline }.from(nil).to(pipelines.first)
          .and change { project_2.reload.vulnerability_statistic }.from(nil).to(an_instance_of(described_class))
          .and change { project_2.reload.vulnerability_statistic&.pipeline }.from(nil).to(pipelines.second)

        expect(project_1.vulnerability_statistic.archived).to eq(project_1.archived)
        expect(project_1.vulnerability_statistic.traversal_ids).to eq(project_1.namespace.traversal_ids)
        expect(project_2.vulnerability_statistic.archived).to eq(project_2.archived)
        expect(project_2.vulnerability_statistic.traversal_ids).to eq(project_2.namespace.traversal_ids)
      end
    end
  end

  context 'loose foreign key on vulnerability_statistics.latest_pipeline_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let!(:parent) { create(:ci_pipeline) }
      let!(:model) { create(:vulnerability_statistic, pipeline: parent) }
    end
  end

  context 'with loose foreign key on vulnerability_statistics.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerability_statistic, project: parent) }
    end
  end
end
