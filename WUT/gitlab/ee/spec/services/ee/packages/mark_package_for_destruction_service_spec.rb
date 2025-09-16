# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::MarkPackageForDestructionService, :aggregate_failures, feature_category: :package_registry do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:package) { create(:npm_package, project: project) }

  let(:service) { described_class.new(container: package, current_user: user) }

  describe '#execute' do
    it 'calls CreateAuditEventService' do
      expect_next_instance_of(
        ::Packages::CreateAuditEventService,
        package,
        current_user: user,
        event_name: 'package_registry_package_deleted'
      ) do |service|
        expect(service).to receive(:execute)
      end

      service.execute
    end
  end
end
