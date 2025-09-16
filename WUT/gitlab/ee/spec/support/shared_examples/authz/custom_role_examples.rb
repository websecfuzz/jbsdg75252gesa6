# frozen_string_literal: true

RSpec.shared_examples 'permission is allowed/disallowed with feature enabled' do
  with_them do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(license => true)
      end

      it { is_expected.to be_disallowed(permission) }

      context 'when admin mode enabled', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(permission) }
      end

      context 'when admin mode disabled' do
        let(:current_user) { admin }

        it { is_expected.to be_disallowed(permission) }
      end
    end

    context 'when feature is disabled' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(license => false)
      end

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_disallowed(permission) }
      end
    end
  end
end

RSpec.shared_examples 'custom role create service returns error' do
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }
  let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }

  it 'is not successful' do
    expect(create_role).to be_error
  end

  it 'returns the correct error messages' do
    expect(create_role.message).to include(error_message)
  end

  it 'does not create the role' do
    expect { create_role }.not_to change { role_class.count }
  end

  it 'does not log an audit event' do
    expect { create_role }.not_to change { AuditEvent.count }
  end
end

RSpec.shared_examples 'custom role creation' do
  let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }
  let(:audit_event_message) { 'Member role was created' }
  let(:audit_event_type) { 'member_role_created' }

  context 'with valid params' do
    it 'is successful' do
      expect(create_role).to be_success
    end

    it 'returns the object with assigned attributes' do
      expect(create_role.payload.name).to eq(role_name)
    end

    it 'creates the role correctly' do
      expect { create_role }.to change { role_class.count }.by(1)

      role = role_class.last
      expect(role.name).to eq(role_name)
      expect(role.permissions.select { |_k, v| v }.symbolize_keys).to eq(abilities)
    end

    include_examples 'audit event logging' do
      let(:licensed_features_to_stub) { { custom_roles: true } }
      let(:operation) { create_role.payload }

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: audit_entity_id,
          entity_type: audit_entity_type,
          details: {
            author_name: user.name,
            event_name: audit_event_type,
            target_id: operation.id,
            target_type: operation.class.name,
            target_details: {
              name: operation.name,
              description: operation.description,
              abilities: abilities.keys.join(', ')
            }.to_s,
            custom_message: audit_event_message,
            author_class: user.class.name
          }
        }
      end
    end
  end
end

RSpec.shared_examples 'custom role update' do
  let(:audit_event_message) { 'Member role was updated' }
  let(:audit_event_type) { 'member_role_updated' }
  let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

  context 'with valid params' do
    it 'is successful' do
      expect(result).to be_success
    end

    it 'updates the provided (permitted) attributes' do
      expect { result }
        .to change { role.reload.name }.to(role_name)
        .and change { role.reload.permissions[existing_abilities.each_key.first.to_s] }.to(false)
    end

    it 'does not update unpermitted attributes' do
      if role.respond_to?(:base_access_level)
        expect { result }.not_to change {
          role.reload.base_access_level
        }
      end
    end

    include_examples 'audit event logging' do
      let(:licensed_features_to_stub) { { custom_roles: true } }
      let(:operation) { result }
      let(:fail_condition!) { allow(role).to receive(:save).and_return(false) }

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: audit_entity_id,
          entity_type: audit_entity_type,
          details: {
            author_name: user.name,
            event_name: audit_event_type,
            target_id: role.id,
            target_type: role.class.name,
            target_details: {
              name: role_name,
              description: role_description,
              abilities: updated_abilities.filter { |_, v| v }.keys.sort.join(', ')
            }.to_s,
            custom_message: audit_event_message,
            author_class: user.class.name
          }
        }
      end
    end
  end

  context 'when member role can not be updated' do
    before do
      error_messages = double

      allow(role).to receive_messages(save: false, errors: error_messages)
      allow(error_messages).to receive(:full_messages).and_return(['this is wrong'])
    end

    it 'is not successful' do
      expect(result).to be_error
    end

    it 'includes the object errors' do
      expect(result.message).to eq('this is wrong')
    end

    it 'does not log an audit event' do
      expect { result }.not_to change { AuditEvent.count }
    end
  end
end

RSpec.shared_examples 'deleting a role' do
  let(:audit_event_message) { 'Member role was deleted' }
  let(:audit_event_type) { 'member_role_deleted' }
  let(:audit_event_abilities) { 'read_code' }
  let(:audit_entity_id) { Gitlab::Audit::InstanceScope.new.id }
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

  it 'is successful' do
    expect(result).to be_success
  end

  it 'deletes the role' do
    result

    expect(role).to be_destroyed
  end

  context 'when failing to delete the role' do
    before do
      errors = ActiveModel::Errors.new(role).tap { |e| e.add(:base, 'error message') }
      allow(role).to receive_messages(destroy: false, errors: errors)
    end

    it 'returns an error message' do
      expect(result).to be_error
      expect(result.message).to eq('error message')
    end

    it 'does not log an audit event' do
      expect { result }.not_to change { AuditEvent.count }
    end
  end

  include_examples 'audit event logging' do
    let(:licensed_features_to_stub) { { custom_roles: true } }
    let(:event_type) { audit_event_type }
    let(:operation) { result }
    let(:fail_condition!) { allow(role).to receive(:destroy).and_return(false) }

    let(:attributes) do
      {
        author_id: user.id,
        entity_id: audit_entity_id,
        entity_type: audit_entity_type,
        details: {
          author_name: user.name,
          target_id: role.id,
          target_type: role.class.name,
          event_name: audit_event_type,
          target_details: {
            name: role.name,
            description: role.description,
            abilities: audit_event_abilities
          }.to_s,
          custom_message: audit_event_message,
          author_class: user.class.name
        }
      }
    end
  end
end

RSpec.shared_examples 'does not call custom role query' do
  it 'detects zero queries to projects preloader' do
    recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { subject }
    method_invocations = recorder.find_query(/.*user_member_roles_in_projects_preloader.rb.*/, 0)

    expect(method_invocations).to be_empty
  end

  it 'detects zero queries to groups preloader' do
    recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { subject }
    method_invocations = recorder.find_query(/.*user_member_roles_in_groups_preloader.rb.*/, 0)

    expect(method_invocations).to be_empty
  end
end
