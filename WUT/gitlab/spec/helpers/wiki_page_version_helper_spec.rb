# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPageVersionHelper, feature_category: :wiki do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:user) { create(:user, username: 'foo') }

  let(:commit_with_user) { create(:commit, project: project, author: user) }
  let(:commit_without_user) { create(:commit, project: project, author_name: 'Foo', author_email: 'foo@example.com') }
  let(:wiki_page_version) { Gitlab::Git::WikiPageVersion.new(commit, nil) }

  describe '#wiki_page_version_author_url' do
    subject { helper.wiki_page_version_author_url(wiki_page_version) }

    context 'when user exists' do
      let(:commit) { commit_with_user }

      it 'returns the link to the user profile' do
        expect(subject).to eq('http://localhost/foo')
      end
    end

    context 'when user does not exist' do
      let(:commit) { commit_without_user }

      it 'returns the mailto link' do
        expect(subject).to eq "mailto:#{commit_without_user.author_email}"
      end
    end
  end
end
