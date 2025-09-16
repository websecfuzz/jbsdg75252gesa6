# frozen_string_literal: true

RSpec.shared_examples 'finding user when user cap is set' do
  context 'when a sign-up user cap has been set' do
    before do
      gl_user.state = ::User::BLOCKED_PENDING_APPROVAL_STATE
      stub_application_setting(new_user_signups_cap: new_user_signups_cap)
      stub_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP)
    end

    context 'when the user cap has been reached' do
      let(:new_user_signups_cap) { 1 }

      it 'does not activate the user' do
        create(:user)

        o_auth_user.save # rubocop:disable Rails/SaveBang

        expect(o_auth_user.find_user).to be_blocked
      end
    end

    context 'when the user cap has not been reached' do
      let(:new_user_signups_cap) { 100 }

      context 'when the user can be activated based on user cap' do
        before do
          stub_omniauth_setting(block_auto_created_users: false)
        end

        it 'activates the user' do
          o_auth_user.save # rubocop:disable Rails/SaveBang

          expect(o_auth_user.find_user).to be_active
        end

        context 'when the query behind .user_cap_reached? times out' do
          it 'tracks query timeout exception' do
            expect(::User).to receive(:user_cap_reached?).once.and_call_original
            expect(::User).to receive(:user_cap_reached?).once.and_raise(ActiveRecord::QueryAborted)

            expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(ActiveRecord::QueryAborted),
              user_email: o_auth_user.gl_user.email
            )

            o_auth_user.save # rubocop:disable Rails/SaveBang
          end
        end
      end

      context 'when the user cannot be activated based on user cap' do
        before do
          allow_next_instance_of(::Gitlab::Auth::Ldap::Config) do |config|
            allow(config).to receive_messages(block_auto_created_users: true)
          end
        end

        it 'does not activate the user' do
          o_auth_user.save # rubocop:disable Rails/SaveBang

          expect(o_auth_user.find_user).to be_blocked
        end
      end
    end
  end
end
