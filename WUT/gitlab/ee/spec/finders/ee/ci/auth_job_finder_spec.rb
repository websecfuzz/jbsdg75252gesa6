# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::AuthJobFinder, feature_category: :continuous_integration do
  describe '#execute!', :request_store do
    subject(:execute) { described_class.new(token: token).execute! }

    context 'when job has a `scoped_user_id` tracked' do
      let(:token) { job.token }
      let(:scoped_user) { create(:user) }

      before do
        job.update!(options: job.options.merge(scoped_user_id: scoped_user.id))
      end

      context 'when job user supports composite identity' do
        let_it_be(:user, reload: true) { create(:user, :service_account, composite_identity_enforced: true) }
        let_it_be(:job, refind: true) { create(:ci_build, status: :running, user: user) }

        it 'links the scoped user as composite identity' do
          expect(job.scoped_user).to eq(scoped_user)

          execute

          expect(::Gitlab::Auth::Identity.new(job.user)).to be_linked
        end
      end
    end
  end
end
