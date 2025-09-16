# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterprise::LeadFormWithErrorsComponent, :saas, :aggregate_failures, type: :component, feature_category: :acquisition do
  let(:errors) { ['first name is missing'] }
  let(:form_params) { {} }
  let(:additional_kwargs) { { form_params: form_params, errors: errors } }

  it_behaves_like GitlabSubscriptions::Trials::DuoEnterprise::LeadFormComponent do
    it { is_expected.to have_text('first name is missing') }

    context 'with form params from failed submission' do
      let(:form_params) do
        {
          first_name: 'foo',
          last_name: 'bar',
          email_domain: 'baz',
          company_name: 'qux',
          phone_number: 'quuz',
          country: 'corge',
          state: 'grault'
        }
      end

      let(:expected_form_data_attributes) do
        {
          first_name: form_params[:first_name],
          last_name: form_params[:last_name],
          email_domain: user.email_domain,
          company_name: form_params[:company_name],
          phone_number: form_params[:phone_number],
          country: form_params[:country],
          state: form_params[:state],
          submit_button_text: 'Continue',
          submit_path: submit_path
        }
      end

      it 'renders form with correct attributes' do
        expect_form_data_attribute(expected_form_data_attributes)
      end
    end
  end
end
