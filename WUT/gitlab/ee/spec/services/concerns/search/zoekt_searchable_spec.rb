# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ZoektSearchable, feature_category: :global_search do
  let(:subject_class) do
    Class.new do
      include Search::ZoektSearchable
    end
  end

  let(:class_instance) { subject_class.new }

  describe '#search_level' do
    it 'raise NotImplementedError' do
      expect { class_instance.search_level }.to raise_error(NotImplementedError)
    end
  end
end
