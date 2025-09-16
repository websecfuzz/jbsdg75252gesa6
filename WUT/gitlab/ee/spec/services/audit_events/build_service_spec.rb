# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::BuildService do
  let(:author) { build_stubbed(:author, current_sign_in_ip: '127.0.0.1') }
  let(:deploy_token) { build_stubbed(:deploy_token, user: author) }
  let(:scope) { build_stubbed(:group) }
  let(:target) { build_stubbed(:project) }
  let(:ip_address) { '192.168.8.8' }
  let(:message) { 'Added an interesting field from project Gotham' }
  let(:additional_details) { { action: :custom } }

  subject(:service) do
    described_class.new(
      author: author,
      scope: scope,
      target: target,
      message: message,
      additional_details: additional_details,
      ip_address: ip_address
    )
  end

  describe '#execute', :request_store do
    subject(:event) { service.execute }

    before do
      allow(Gitlab::RequestContext.instance).to receive(:client_ip).and_return(ip_address)
    end

    context 'when licensed' do
      before do
        stub_licensed_features(admin_audit_log: true)
      end

      it 'sets correct attributes', :aggregate_failures do
        freeze_time do
          expect(event).to have_attributes(
            author_id: author.id,
            author_name: author.name,
            entity_id: scope.id,
            entity_type: scope.class.name)

          expect(event.details).to eq(
            author_name: author.name,
            author_class: author.class.name,
            target_id: target.id,
            target_type: target.class.name,
            target_details: target.name,
            custom_message: message,
            ip_address: ip_address,
            entity_path: scope.full_path,
            action: :custom)

          expect(event.ip_address).to eq(ip_address)
          expect(event.created_at).to eq(DateTime.current)
        end
      end

      context 'when IP address is not provided' do
        let(:ip_address) { nil }

        it 'uses author current_sign_in_ip' do
          expect(event.ip_address).to eq(author.current_sign_in_ip)
        end
      end

      context 'when author is impersonated' do
        let(:impersonator) { build_stubbed(:user, name: 'Agent Donald', current_sign_in_ip: '8.8.8.8') }
        let(:author) { build_stubbed(:author, impersonator: impersonator) }

        it 'sets author to impersonated user', :aggregate_failures do
          expect(event.author_id).to eq(author.id)
          expect(event.author_name).to eq(author.name)
        end

        it 'includes impersonator name in message' do
          expect(event.details[:custom_message])
            .to eq('Added an interesting field from project Gotham (by Agent Donald)')
        end

        context 'when IP address is not provided' do
          let(:ip_address) { nil }

          it 'uses impersonator current_sign_in_ip' do
            expect(event.ip_address).to eq(impersonator.current_sign_in_ip)
          end
        end
      end

      context 'when overriding target details' do
        subject(:service) do
          described_class.new(
            author: author,
            scope: scope,
            target: target,
            message: message,
            target_details: "This is my target details"
          )
        end

        it 'uses correct target details' do
          expect(event.target_details).to eq("This is my target details")
        end
      end

      context 'when deploy token is passed as author' do
        let(:service) do
          described_class.new(
            author: deploy_token,
            scope: scope,
            target: target,
            message: message
          )
        end

        it 'expect author to be user' do
          expect(event.author_id).to eq(-2)
          expect(event.author_name).to eq(deploy_token.name)
        end
      end

      context 'when deploy key is passed as author' do
        let(:deploy_key) { build_stubbed(:deploy_key, user: author) }

        let(:service) do
          described_class.new(
            author: deploy_key,
            scope: scope,
            target: target,
            message: message
          )
        end

        it 'expect author to be deploy key' do
          expect(event.author_id).to eq(-3)
          expect(event.author_name).to eq(deploy_key.name)
        end
      end

      context 'when author is passed as UnauthenticatedAuthor' do
        let(:service) do
          described_class.new(
            author: ::Gitlab::Audit::UnauthenticatedAuthor.new,
            scope: scope,
            target: target,
            message: message
          )
        end

        it 'sets author as unauthenticated user' do
          expect(event.author).to be_an_instance_of(::Gitlab::Audit::UnauthenticatedAuthor)
          expect(event.author_name).to eq('An unauthenticated user')
        end
      end

      context 'when author is a CiRunnerTokenAuthor' do
        let(:service) do
          described_class.new(
            author: ::Gitlab::Audit::CiRunnerTokenAuthor.new(
              entity_type: 'Group',
              entity_path: 'a/b',
              runner_authentication_token: 'token'
            ),
            scope: scope,
            target: target,
            message: message
          )
        end

        it 'sets author as unauthenticated user' do
          expect(event.author).to be_an_instance_of(::Gitlab::Audit::UnauthenticatedAuthor)
          expect(event.author_name).to eq('Authentication token: token')
        end
      end
    end

    context 'when not licensed' do
      before do
        stub_licensed_features(admin_audit_log: false)
      end

      it 'sets correct attributes', :aggregate_failures do
        freeze_time do
          expect(event).to have_attributes(
            author_id: author.id,
            author_name: author.name,
            entity_id: scope.id,
            entity_type: scope.class.name)

          expect(event.details).to eq(
            author_name: author.name,
            author_class: author.class.name,
            target_id: target.id,
            target_type: target.class.name,
            target_details: target.name,
            custom_message: message,
            action: :custom)

          expect(event.ip_address).to be_nil
          expect(event.created_at).to eq(DateTime.current)
        end
      end

      context 'when author is impersonated' do
        let(:impersonator) { build_stubbed(:user, name: 'Agent Donald', current_sign_in_ip: '8.8.8.8') }
        let(:author) { build_stubbed(:author, impersonator: impersonator) }

        it 'does not includes impersonator name in message' do
          expect(event.details[:custom_message])
            .to eq('Added an interesting field from project Gotham')
        end
      end
    end
  end
end
