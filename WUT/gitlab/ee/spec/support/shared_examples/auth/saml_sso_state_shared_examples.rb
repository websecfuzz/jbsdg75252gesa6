# frozen_string_literal: true

RSpec.shared_examples_for 'SAML SSO State checks for session_not_on_or_after' do |saml_type|
  describe '#active_since?' do
    let(:cutoff) { 1.week.ago }

    context 'when session_not_on_or_after is supplied' do
      context 'when session has expired' do
        let(:expired_time) { 1.hour.ago.iso8601 }

        it 'returns false even if cutoff is met' do
          time_after_cut_off = cutoff + 2.days

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => time_after_cut_off,
              "#{saml_provider_id}_session_not_on_or_after" => expired_time
            }
                                        ) do
              is_expected.not_to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => time_after_cut_off,
                                    'session_not_on_or_after' => expired_time }
            }
                                        ) do
              is_expected.not_to be_active_since(cutoff)
            end
          end
        end

        it 'returns false when cutoff is not met' do
          time_before_cut_off = cutoff - 2.days

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => time_before_cut_off,
              "#{saml_provider_id}_session_not_on_or_after" => expired_time
            }) do
              is_expected.not_to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => time_before_cut_off,
                                    'session_not_on_or_after' => expired_time }
            }
                                        ) do
              is_expected.not_to be_active_since(cutoff)
            end
          end
        end
      end

      context 'when session has not expired' do
        let(:future_time) { 1.hour.from_now.iso8601 }
        let(:last_signin_time_in_future) { 3.hours.from_now }

        it 'returns true' do
          cutoff = 2.hours.ago

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => last_signin_time_in_future,
              "#{saml_provider_id}_session_not_on_or_after" => future_time
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => last_signin_time_in_future,
                                    'session_not_on_or_after' => future_time }
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end
        end

        it 'returns true and cutoff value is not considered' do
          cutoff = 4.hours.from_now

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => last_signin_time_in_future,
              "#{saml_provider_id}_session_not_on_or_after" => future_time
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => last_signin_time_in_future,
                                    'session_not_on_or_after' => future_time }
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end
        end
      end

      context 'when session_not_on_or_after is not set' do
        it 'considers cutoff value to decide sso_state active' do
          cutoff = 2.hours.ago

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => Time.current
            }) do
              is_expected.to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => Time.current }
            }
                                        ) do
              is_expected.to be_active_since(cutoff)
            end
          end
        end
      end

      context 'when feature flag is disabled' do
        let(:last_signin_time) { 4.hours.ago }
        let(:future_time) { 1.hour.from_now.iso8601 }

        before do
          stub_feature_flags(saml_timeout_supplied_by_idp_override: false)
        end

        it 'considers cutoff value to decide sso_state active' do
          cutoff = 2.hours.ago

          if saml_type == 'group'
            Gitlab::Session.with_session(active_group_sso_sign_ins: {
              saml_provider_id => last_signin_time,
              "#{saml_provider_id}_session_not_on_or_after" => future_time
            }) do
              is_expected.not_to be_active_since(cutoff)
            end
          end

          if saml_type == 'instance'
            Gitlab::Session.with_session(active_instance_sso_sign_ins: {
              saml_provider_id => { 'last_signin_at' => last_signin_time,
                                    'session_not_on_or_after' => future_time }
            }) do
              is_expected.not_to be_active_since(cutoff)
            end
          end
        end
      end
    end
  end

  describe '#saml_session_active?' do
    let(:session_data) { Time.current }

    context 'when session_not_on_or_after is not present' do
      it 'returns false' do
        if saml_type == 'group'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(session_data, session_not_on_or_after: nil)
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end

        if saml_type == 'instance'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(time: session_data, session_not_on_or_after: nil)
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end
      end
    end

    context 'when session_not_on_or_after is blank string' do
      it 'returns false' do
        if saml_type == 'group'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(session_data, session_not_on_or_after: '')
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end

        if saml_type == 'instance'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(time: session_data, session_not_on_or_after: '')
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end
      end
    end

    context 'when session_not_on_or_after is in the future' do
      let(:future_expiry) { 2.hours.from_now.utc.iso8601 }

      it 'returns true' do
        if saml_type == 'group'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(session_data, session_not_on_or_after: future_expiry)
            expect(sso_state.send(:saml_session_active?)).to be(true)
          end
        end

        if saml_type == 'instance'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(time: session_data, session_not_on_or_after: future_expiry)
            expect(sso_state.send(:saml_session_active?)).to be(true)
          end
        end
      end
    end

    context 'when session_not_on_or_after is in the past' do
      let(:past_expiry) { 1.hour.ago.utc.iso8601 }

      it 'returns false' do
        if saml_type == 'group'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(session_data, session_not_on_or_after: past_expiry)
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end

        if saml_type == 'instance'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(time: session_data, session_not_on_or_after: past_expiry)
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end
      end
    end

    context 'when session_not_on_or_after is exactly current time' do
      let(:current_expiry) { Time.current.utc.iso8601 }

      it 'returns false (expired at current moment)' do
        if saml_type == 'group'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(session_data, session_not_on_or_after: current_expiry)
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end

        if saml_type == 'instance'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(time: session_data, session_not_on_or_after: current_expiry)
            expect(sso_state.send(:saml_session_active?)).to be(false)
          end
        end
      end
    end

    context 'when session_not_on_or_after has milliseconds' do
      let(:future_with_ms) { 1.hour.from_now.utc.strftime('%Y-%m-%dT%H:%M:%S.%3NZ') }

      it 'returns true' do
        if saml_type == 'group'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(session_data, session_not_on_or_after: future_with_ms)
            expect(sso_state.send(:saml_session_active?)).to be(true)
          end
        end

        if saml_type == 'instance'
          Gitlab::Session.with_session({}) do
            sso_state.update_active(time: session_data, session_not_on_or_after: future_with_ms)
            expect(sso_state.send(:saml_session_active?)).to be(true)
          end
        end
      end
    end
  end
end
