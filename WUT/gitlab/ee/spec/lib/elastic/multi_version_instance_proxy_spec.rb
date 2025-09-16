# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::MultiVersionInstanceProxy do
  let(:snippet) { create(:project_snippet) }

  subject { described_class.new(snippet) }

  describe '#version' do
    it 'returns instance proxy in specified version' do
      result = subject.version('Latest')

      expect(result).to be_a(Elastic::Latest::SnippetInstanceProxy)
      expect(result.target).to eq(snippet)
    end

    context 'repository' do
      let(:project) { create(:project, :repository) }
      let(:repository) { project.repository }
      let(:wiki) { project.wiki }

      it 'returns instance proxy in specified version' do
        repository_proxy = described_class.new(repository)
        repository_result = repository_proxy.version('Latest')
        wiki_proxy = described_class.new(wiki)
        wiki_result = wiki_proxy.version('Latest')

        expect(repository_result).to be_a(Elastic::Latest::RepositoryInstanceProxy)
        expect(repository_result.target).to eq(repository)
        expect(wiki_result).to be_a(Elastic::Latest::WikiInstanceProxy)
        expect(wiki_result.target).to eq(wiki)
      end
    end
  end

  describe 'method forwarding' do
    let(:old_target) { double(:old_target) }
    let(:new_target) { double(:new_target) }
    let(:response) do
      { "_index" => "gitlab-test", "_type" => "doc", "_id" => "snippet_1", "_version" => 3, "result" => "updated", "_shards" => { "total" => 2, "successful" => 1, "failed" => 0 }, "created" => false }
    end

    before do
      allow(subject).to receive(:elastic_reading_target).and_return(old_target)
      allow(subject).to receive(:elastic_writing_targets).and_return([old_target, new_target])
    end

    it 'forwards methods which should touch all write targets' do
      Elastic::Latest::SnippetInstanceProxy.methods_for_all_write_targets.each do |method|
        expect(new_target).to receive(method).and_return(response)
        expect(old_target).to receive(method).and_return(response)

        subject.public_send(method)
      end
    end

    it 'forwards read methods to only reading target' do
      expect(old_target).to receive(:as_indexed_json)
      expect(new_target).not_to receive(:as_indexed_json)

      subject.as_indexed_json

      expect(subject).not_to respond_to(:method_missing)
    end

    it 'does not forward write methods which should touch specific version' do
      Elastic::Latest::SnippetInstanceProxy.methods_for_one_write_target.each do |method|
        expect(subject).not_to respond_to(method)
      end
    end
  end
end
