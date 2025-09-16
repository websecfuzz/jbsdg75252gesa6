# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Entry::GitlabSecretsManager::Secret, feature_category: :secrets_management do
  let(:entry) { described_class.new(config) }

  before do
    entry.compose!
  end

  describe 'validations' do
    context 'when all config value is correct' do
      let(:config) do
        {
          name: 'name'
        }
      end

      it { expect(entry).to be_valid }
    end

    context 'when name is nil' do
      let(:config) do
        {
          name: nil
        }
      end

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret name can\'t be blank'
      end
    end

    context 'when there is an unknown key present' do
      let(:config) { { foo: :bar } }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include "secret name can't be blank"
      end
    end

    context 'when config is not a hash' do
      let(:config) { "" }

      it { expect(entry).not_to be_valid }

      it 'reports error' do
        expect(entry.errors)
          .to include 'secret config should be a hash'
      end
    end
  end

  describe '#value' do
    context 'when config is valid' do
      let(:config) do
        {
          name: 'name'
        }
      end

      let(:result) do
        {
          name: "name"
        }
      end

      it 'returns config' do
        expect(entry.value).to eq(result)
      end
    end
  end
end
