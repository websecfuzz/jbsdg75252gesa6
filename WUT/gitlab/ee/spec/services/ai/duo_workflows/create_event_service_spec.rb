# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CreateEventService, type: :service, feature_category: :duo_workflow do
  let(:workflow) { create(:duo_workflows_workflow) }
  let_it_be(:project) { create(:project) }
  let(:valid_params) do
    {
      event_type: 'pause',
      event_status: 'queued',
      message: 'This is a test message'
    }
  end

  let(:invalid_params) do
    {
      event_status: 'queued' # Missing event_type
    }
  end

  describe '#execute' do
    context 'when valid parameters are provided' do
      it 'creates a new event and returns success' do
        service = described_class.new(project: project, workflow: workflow, params: valid_params)
        result = service.execute

        expect(result[:status]).to eq(:success)
        expect(result[:event]).to be_persisted
        expect(result[:event].event_type).to eq('pause')
        expect(result[:event].event_status).to eq('queued')
        expect(result[:event].message).to eq('This is a test message')
      end
    end

    context 'when invalid parameters are provided' do
      it 'does not create an event and returns an error' do
        service = described_class.new(project: project, workflow: workflow, params: invalid_params)
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include("Event type can't be blank")
      end
    end
  end

  describe '#event_attributes' do
    it 'merges params with workflow and project' do
      service = described_class.new(project: project, workflow: workflow, params: valid_params)
      attributes = service.event_attributes

      expect(attributes[:workflow]).to eq(workflow)
      expect(attributes[:project]).to eq(project)
      expect(attributes[:event_type]).to eq('pause')
      expect(attributes[:event_status]).to eq('queued')
      expect(attributes[:message]).to eq('This is a test message')
    end
  end
end
