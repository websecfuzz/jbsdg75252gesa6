# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Pages::Domains::UpdateService, feature_category: :pages do
  let_it_be(:user) { create(:user) }
  let_it_be(:pages_domain) { create(:pages_domain) }

  let(:params) do
    attributes_for(:pages_domain, :with_trusted_chain).slice(:key, :certificate).tap do |params|
      params[:user_provided_key] = params.delete(:key)
      params[:user_provided_certificate] = params.delete(:certificate)
    end
  end

  subject(:service) { described_class.new(pages_domain.project, user, params) }

  context 'when the user does not have the required permissions' do
    it 'does not update the pages domain and does not publish a PagesDomainUpdatedEvent' do
      expect do
        expect(service.execute(pages_domain)).to be_nil
      end.to not_publish_event(::Pages::Domains::PagesDomainUpdatedEvent)
    end
  end

  context 'when the user has the required permissions' do
    before do
      pages_domain.project.add_maintainer(user)
    end

    context 'when it updates the domain successfully' do
      it 'updates the domain' do
        expect(service.execute(pages_domain)).to be true
      end

      it 'publishes a PagesDomainUpdatedEvent' do
        expect { service.execute(pages_domain) }
          .to publish_event(::Pages::Domains::PagesDomainUpdatedEvent)
          .with(
            project_id: pages_domain.project.id,
            namespace_id: pages_domain.project.namespace.id,
            root_namespace_id: pages_domain.project.root_namespace.id,
            domain_id: pages_domain.id,
            domain: pages_domain.domain
          )
      end
    end

    context 'when it fails to update the domain' do
      let(:params) { { user_provided_certificate: 'blabla' } }

      it 'does not update a pages domain' do
        expect(service.execute(pages_domain)).to be(false)
      end

      it 'does not publish a PagesDomainUpdatedEvent' do
        expect { service.execute(pages_domain) }
          .not_to publish_event(::Pages::Domains::PagesDomainUpdatedEvent)
      end
    end
  end
end
