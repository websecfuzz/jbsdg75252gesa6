# frozen_string_literal: true

RSpec.shared_examples 'members response with exposed email' do
  it { is_expected.to include(a_hash_including('email' => email)) }
end

RSpec.shared_examples 'members response with hidden email' do
  it { is_expected.not_to include(a_hash_including('email' => email)) }
end

RSpec.shared_examples 'member response with exposed email' do
  it { is_expected.to include('email' => email) }
end

RSpec.shared_examples 'member response with hidden email' do
  it { is_expected.not_to have_key('email') }
end
