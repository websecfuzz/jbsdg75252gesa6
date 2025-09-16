# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::AuditEvents::GroupAuditEvent, type: :model, feature_category: :audit_events do
  describe '#entity' do
    let_it_be(:group_audit_event_1) { create(:audit_events_group_audit_event) }

    it 'returns group' do
      expect(group_audit_event_1.entity).to eq(group_audit_event_1.group)
    end
  end

  describe '#entity_type' do
    let_it_be(:group_audit_event_1) { create(:audit_events_group_audit_event) }

    it 'returns group' do
      expect(group_audit_event_1.entity_type).to eq("Group")
    end
  end

  describe '#present' do
    let_it_be(:group_audit_event_1) { create(:audit_events_group_audit_event) }

    it 'returns a presenter' do
      expect(group_audit_event_1.present).to be_an_instance_of(AuditEventPresenter)
    end
  end

  describe '#root_group_entity' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_group) }

    context 'when root_group_entity_id is set' do
      subject(:event) { described_class.new(root_group_entity_id: root_group.id) }

      it "return root_group_entity through root_group_entity_id" do
        expect(event.root_group_entity).to eq(root_group)
      end
    end

    context "when group is nil" do
      subject(:event) { described_class.new(group: nil) }

      it "return nil" do
        expect(event.root_group_entity).to be_nil
      end
    end

    subject(:event) { described_class.new(group: group) }

    it "return root_group and set root_group_entity_id" do
      expect(event.root_group_entity).to eq(root_group)
      expect(event.root_group_entity_id).to eq(root_group.id)
    end
  end

  it_behaves_like 'streaming audit event model'
end
