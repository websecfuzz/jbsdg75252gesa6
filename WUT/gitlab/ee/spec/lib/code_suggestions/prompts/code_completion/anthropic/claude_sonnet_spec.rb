# frozen_string_literal: true

require 'spec_helper'
require_relative 'anthropic_shared_examples'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::Anthropic::ClaudeSonnet, feature_category: :code_suggestions do
  it_behaves_like 'anthropic code completion' do
    let(:model_name) { 'claude-3-5-sonnet-20240620' }
  end
end
