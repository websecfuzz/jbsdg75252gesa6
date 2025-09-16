# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PushRule, :saas, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  let(:global_push_rule) { create(:push_rule_sample) }
  let(:push_rule) { create(:push_rule) }
  let(:user) { create(:user) }
  let(:project) { Projects::CreateService.new(user, { name: 'test', namespace: user.namespace }).execute }

  it_behaves_like 'cleanup by a loose foreign key' do
    let!(:parent) { create(:organization) }
    let!(:model) { create(:push_rule_without_project, organization: parent) }
  end

  it_behaves_like 'a push ruleable model'

  describe "Associations" do
    it { is_expected.to belong_to(:project).inverse_of(:push_rule) }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_one(:group).inverse_of(:push_rule).autosave(true) }
  end

  describe "Validations" do
    it 'validates RE2 regex syntax' do
      push_rule = build(:push_rule, branch_name_regex: '(ee|ce).*\1')

      expect(push_rule).not_to be_valid
      expect(push_rule.errors.full_messages.join).to match(/invalid escape sequence/)
    end
  end

  it 'always sets regexp_uses_re2 to true' do
    push_rule = create(:push_rule)
    expect(push_rule.regexp_uses_re2).to eq(true)

    push_rule.regexp_uses_re2 = false
    expect(push_rule.regexp_uses_re2).to eq(true)

    push_rule.save!
    expect(push_rule.reload.regexp_uses_re2).to eq(true)
  end

  it 'cannot set regexp_uses_re2 to false' do
    push_rule = create(:push_rule)

    push_rule.regexp_uses_re2 = false
    expect(push_rule.regexp_uses_re2).to eq(true)

    push_rule.update_column(:regexp_uses_re2, false)
    push_rule.reload

    push_rule.save!
    expect(push_rule.reload.regexp_uses_re2).to eq(true)
  end

  describe '#branch_name_allowed?' do
    subject(:push_rule) { create(:push_rule, branch_name_regex: '\d+\-.*') }

    it 'always uses RE2 regex engine' do
      expect_any_instance_of(Gitlab::UntrustedRegexp).to receive(:===)

      subject.branch_name_allowed?('123-feature')
    end
  end

  describe '#commit_validation?' do
    let(:settings_with_global_default) { %i[reject_unsigned_commits] }

    where(:setting, :value, :result) do
      :commit_message_regex        | 'regex'       | true
      :branch_name_regex           | 'regex'       | true
      :author_email_regex          | 'regex'       | true
      :file_name_regex             | 'regex'       | true
      :reject_unsigned_commits     | true          | true
      :commit_committer_check      | true          | true
      :commit_committer_name_check | true          | true
      :member_check                | true          | true
      :prevent_secrets             | true          | true
      :max_file_size               | 1             | false
    end

    with_them do
      context "when rule is enabled at global level" do
        before do
          stub_feature_flags(inherited_push_rule_for_project: false)
          global_push_rule.update_column(setting, value)
        end

        it "returns the default value at project level" do
          rule = project.push_rule

          if settings_with_global_default.include?(setting)
            rule.update_column(setting, nil)
          end

          expect(rule.commit_validation?).to eq(result)
        end
      end
    end
  end

  describe '#commit_signature_allowed?' do
    let!(:premium_license) { create(:license, plan: License::PREMIUM_PLAN) }
    let(:signed_commit) { instance_double(Commit, has_signature?: true) }
    let(:unsigned_commit) { instance_double(Commit, has_signature?: false) }

    context 'when feature is not licensed and it is enabled' do
      before do
        stub_licensed_features(reject_unsigned_commits: false)
        global_push_rule.update_attribute(:reject_unsigned_commits, true)
      end

      it 'accepts unsigned commits' do
        expect(push_rule.commit_signature_allowed?(unsigned_commit)).to eq(true)
      end
    end

    context 'when enabled at a global level' do
      before do
        global_push_rule.update_attribute(:reject_unsigned_commits, true)
      end

      it 'returns false if commit is not signed' do
        expect(push_rule.commit_signature_allowed?(unsigned_commit)).to eq(false)
      end

      context 'and disabled at a Project level' do
        it 'returns true if commit is not signed' do
          push_rule.update_attribute(:reject_unsigned_commits, false)

          expect(push_rule.commit_signature_allowed?(unsigned_commit)).to eq(true)
        end
      end

      context 'and unset at a Project level' do
        it 'returns false if commit is not signed' do
          push_rule.update_attribute(:reject_unsigned_commits, nil)

          expect(push_rule.commit_signature_allowed?(unsigned_commit)).to eq(false)
        end
      end
    end

    context 'when disabled at a global level' do
      before do
        global_push_rule.update_attribute(:reject_unsigned_commits, false)
      end

      it 'returns true if commit is not signed' do
        expect(push_rule.commit_signature_allowed?(unsigned_commit)).to eq(true)
      end

      context 'but enabled at a Project level' do
        before do
          push_rule.update_attribute(:reject_unsigned_commits, true)
        end

        it 'returns false if commit is not signed' do
          expect(push_rule.commit_signature_allowed?(unsigned_commit)).to eq(false)
        end

        it 'returns true if commit is signed' do
          expect(push_rule.commit_signature_allowed?(signed_commit)).to eq(true)
        end
      end

      context 'when user has enabled and disabled it at a project level' do
        before do
          # Let's test with the same boolean values that are sent through the form
          push_rule.update_attribute(:reject_unsigned_commits, '1')
          push_rule.update_attribute(:reject_unsigned_commits, '0')
        end

        context 'and it is enabled globally' do
          before do
            global_push_rule.update_attribute(:reject_unsigned_commits, true)
          end

          it 'returns false if commit is not signed' do
            expect(push_rule.commit_signature_allowed?(unsigned_commit)).to eq(false)
          end

          it 'returns true if commit is signed' do
            expect(push_rule.commit_signature_allowed?(signed_commit)).to eq(true)
          end
        end
      end
    end
  end

  context 'with caching', :request_store do
    let(:push_rule_second) { create(:push_rule) }

    it 'memoizes the right push rules' do
      expect(described_class).to receive(:global).twice.and_return(global_push_rule)
      expect(global_push_rule).to receive(:public_send).with(:commit_committer_check).and_return(false)
      expect(global_push_rule).to receive(:public_send).with(:reject_unsigned_commits).and_return(true)

      2.times do
        expect(push_rule.commit_committer_check).to be_falsey
        expect(push_rule_second.reject_unsigned_commits).to be_truthy
      end
    end
  end

  describe '#available?' do
    shared_examples 'an unavailable push_rule' do
      it 'is not available' do
        expect(push_rule.available?(:reject_unsigned_commits)).to eq(false)
      end
    end

    shared_examples 'an available push_rule' do
      it 'is available' do
        expect(push_rule.available?(:reject_unsigned_commits)).to eq(true)
      end
    end

    describe 'reject_unsigned_commits' do
      context 'with the global push_rule' do
        let(:push_rule) { create(:push_rule_sample) }

        context 'with a EE starter license' do
          let!(:license) { create(:license, plan: License::STARTER_PLAN) }

          it_behaves_like 'an unavailable push_rule'
        end

        context 'with a EE premium license' do
          let!(:license) { create(:license, plan: License::PREMIUM_PLAN) }

          it_behaves_like 'an available push_rule'
        end
      end

      context 'with GL.com plans' do
        let(:group) { create(:group) }
        let(:plan) { :free }
        let!(:gitlab_subscription) { create(:gitlab_subscription, plan, namespace: group) }
        let(:project) { create(:project, namespace: group) }
        let(:push_rule) { create(:push_rule, project: project) }

        before do
          create(:license, plan: License::PREMIUM_PLAN)
          stub_application_setting(check_namespace_plan: true)
        end

        shared_examples 'different payment plans verifications' do
          context 'with a Bronze plan' do
            let(:plan) { :bronze }

            it_behaves_like 'an unavailable push_rule'
          end

          context 'with a Premium plan' do
            let(:plan) { :premium }

            it_behaves_like 'an available push_rule'
          end

          context 'with a Ultimate plan' do
            let(:plan) { :ultimate }

            it_behaves_like 'an available push_rule'
          end
        end

        it_behaves_like 'different payment plans verifications'

        context 'when a push rule belongs to a group' do
          let(:push_rule) { create(:push_rule_without_project, group: group) }

          it_behaves_like 'different payment plans verifications'
        end
      end
    end
  end
end
