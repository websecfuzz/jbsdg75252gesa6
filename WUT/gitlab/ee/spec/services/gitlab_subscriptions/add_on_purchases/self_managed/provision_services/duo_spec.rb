# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::Duo,
  feature_category: :'add-on_provisioning' do
  let(:duo_exclusive_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoExclusive
  end

  let(:duo_self_hosted_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoSelfHosted
  end

  let(:duo_core_class) do
    GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::DuoCore
  end

  describe '::DUO_PROVISION_SERVICES' do
    subject { described_class::DUO_PROVISION_SERVICES }

    it { is_expected.to match_array([duo_exclusive_class, duo_self_hosted_class, duo_core_class]) }
  end

  describe '#execute' do
    subject(:duo_service) { described_class.new }

    let(:duo_service_classes) do
      [
        duo_exclusive_class,
        duo_self_hosted_class,
        duo_core_class
      ]
    end

    context 'when all Duo provision service responses are the same status' do
      let!(:duo_services) do
        duo_service_classes.map do |service_class|
          instance_double(service_class).tap do |service|
            allow(service_class).to receive(:new).and_return(service)
            allow(service).to receive(:execute).and_return(service_response)
          end
        end
      end

      context 'when all services succeed' do
        let_it_be(:add_on_purchase) do
          build_stubbed(:gitlab_subscription_add_on_purchase)
        end

        let(:service_response) do
          successful_service_response(add_on_purchase)
        end

        it 'returns success response', :aggregate_failures do
          result = duo_service.execute

          expect(duo_services).to all(have_received(:execute))
          expect(result.message).to eq('Successfully processed Duo add-ons')
          expect(result.payload).to eq({ add_on_purchases: [add_on_purchase] * 3 })
        end
      end

      context 'when all services fail' do
        let(:error_message) { 'an error message' }

        let(:service_response) do
          ServiceResponse.error(message: error_message)
        end

        it 'returns error response', :aggregate_failures do
          result = duo_service.execute

          expect(duo_services).to all(have_received(:execute))
          expect(result.payload).to eq({ add_on_purchases: [] })
          expect(result.message).to eq(
            "Error processing one or more Duo add-ons: #{([error_message] * 3).join(', ')}"
          )
        end
      end
    end

    context 'when Duo provision services return mixed status responses' do
      let_it_be(:duo_pro_add_on) do
        build_stubbed(:gitlab_subscription_add_on_purchase, :duo_pro)
      end

      let_it_be(:duo_core_add_on) do
        build_stubbed(:gitlab_subscription_add_on_purchase, :duo_core)
      end

      let(:duo_exclusive_instance) { instance_double(duo_exclusive_class) }
      let(:duo_self_hosted_instance) { instance_double(duo_self_hosted_class) }
      let(:duo_core_instance) { instance_double(duo_core_class) }

      before do
        allow(duo_exclusive_class).to receive(:new).and_return(duo_exclusive_instance)
        allow(duo_self_hosted_class).to receive(:new).and_return(duo_self_hosted_instance)
        allow(duo_core_class).to receive(:new).and_return(duo_core_instance)
      end

      context 'when some service responses do not contain an add-on purchase' do
        let_it_be(:duo_self_hosted_add_on) { nil }

        before do
          allow(duo_exclusive_instance).to receive(:execute)
            .and_return(successful_service_response(duo_pro_add_on))

          allow(duo_self_hosted_instance).to receive(:execute)
            .and_return(successful_service_response(duo_self_hosted_add_on))

          allow(duo_core_instance).to receive(:execute)
            .and_return(successful_service_response(duo_core_add_on))
        end

        it 'returns success response with only the available add-on purchases', :aggregate_failures do
          result = duo_service.execute

          expect(result.message).to eq('Successfully processed Duo add-ons')
          expect(result.payload).to eq(
            { add_on_purchases: [duo_pro_add_on, duo_core_add_on] }
          )
        end
      end

      context 'when some service responses are successful and others return errors' do
        before do
          allow(duo_exclusive_instance).to receive(:execute)
            .and_return(successful_service_response(duo_pro_add_on))

          allow(duo_self_hosted_instance).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'an error message'))

          allow(duo_core_instance).to receive(:execute)
            .and_return(successful_service_response(duo_core_add_on))
        end

        it 'returns an error response', :aggregate_failures do
          result = duo_service.execute

          expect(result.message).to eq(
            'Error processing one or more Duo add-ons: an error message'
          )

          expect(result.payload).to eq(
            { add_on_purchases: [duo_pro_add_on, duo_core_add_on] }
          )
        end
      end
    end
  end

  private

  def successful_service_response(add_on_purchase)
    ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
  end
end
