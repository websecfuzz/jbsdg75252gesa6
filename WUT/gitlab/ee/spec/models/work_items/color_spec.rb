# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Color, feature_category: :portfolio_management do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:work_items_colors) }
    it { is_expected.to belong_to(:work_item).with_foreign_key('issue_id').inverse_of(:color) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:color) }
  end

  it 'ensures to use work_item namespace' do
    work_item = create(:work_item)
    date_source = described_class.new(work_item: work_item)

    date_source.valid?

    expect(date_source.namespace).to eq(work_item.namespace)
  end

  describe '#text_color' do
    using RSpec::Parameterized::TableSyntax

    where(:epic_color, :expected_text_color) do
      WorkItems::Color::DEFAULT_COLOR | ::Gitlab::Color.of('#FFFFFF')
      ::Gitlab::Color.of('#FFFFFF') | ::Gitlab::Color.of('#1F1E24')
      ::Gitlab::Color.of('#000000') | ::Gitlab::Color.of('#FFFFFF')
    end

    with_them do
      it 'returns correct text color' do
        color = build(:color, color: epic_color)

        expect(color.text_color).to be_color(expected_text_color)
      end
    end
  end
end
