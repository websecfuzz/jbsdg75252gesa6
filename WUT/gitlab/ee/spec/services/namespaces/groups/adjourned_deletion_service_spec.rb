# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Groups::AdjournedDeletionService, feature_category: :groups_and_projects do
  let_it_be(:delay) { 1.hour }
  let_it_be(:params) { { delay: delay } }
  let_it_be_with_reload(:group) { create(:group) }
  let(:resource) { group }
  let(:destroy_worker) { GroupDestroyWorker }
  let(:destroy_worker_params) { [delay, resource.id, user.id] }
  let(:perform_method) { :perform_in }

  subject(:service) { described_class.new(group: group, current_user: user, params: params) }

  include_examples 'adjourned deletion service'
end
