# frozen_string_literal: true

RSpec.shared_examples GitlabSubscriptions::Trials::Ultimate::TrialFormComponent do
  let(:eligible_namespaces) { Group.none }
  let(:user) { build(:user) }
  let(:form_params) do
    {
      glm_source: 'some-source',
      glm_content: 'some-content',
      namespace_id: 1
    }.with_indifferent_access
  end

  let(:kwargs) do
    { user: user, params: form_params, eligible_namespaces: eligible_namespaces }.merge(additional_kwargs)
  end

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  context 'with default content' do
    let(:expected_form_data_attributes) do
      {
        userData: {
          firstName: user.first_name,
          lastName: user.last_name,
          emailDomain: user.email_domain,
          companyName: user.user_detail_organization,
          showNameFields: false,
          phoneNumber: nil,
          country: '',
          state: ''
        },
        submitPath: trials_path(step: 'full', glm_source: 'some-source', glm_content: 'some-content'),
        gtmSubmitEventLabel: 'saasTrialSubmit'
      }.with_indifferent_access
    end

    it { is_expected.to have_content(s_('Trial|Start your free trial')) }

    it 'has body content' do
      is_expected
        .to have_content(s_('Trial|We need a few more details from you to activate your trial.'))
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'has advantages section' do
      is_expected.to have_content(s_('InProductMarketing|No credit card required.'))
    end
  end

  context 'when namespace_id is not provided' do
    let(:form_params) { super().except(:namespace_id) }
    let(:expected_form_data_attributes) do
      {
        namespaceData: {
          anyTrialEligibleNamespaces: false,
          initialValue: '',
          items: []
        }.merge(extra_namespace_data),
        submitPath: trials_path(step: 'full', glm_source: 'some-source', glm_content: 'some-content')
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  context 'when glm_params are not provided' do
    let(:form_params) { super().except(:glm_source, :glm_content) }
    let(:expected_form_data_attributes) do
      { submitPath: trials_path(step: 'full') }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  describe 'with single eligible namespace' do
    let(:group) { build_stubbed(:group) }
    let(:form_params) { super().except(:namespace_id) }
    let(:eligible_namespaces) { [group] }
    let(:expected_form_data_attributes) do
      {
        namespaceData: {
          anyTrialEligibleNamespaces: true,
          initialValue: group.id.to_s,
          items: [
            {
              text: eligible_namespaces.first.name,
              value: eligible_namespaces.first.id.to_s
            }
          ]
        }.merge(extra_namespace_data),
        submitPath: trials_path(step: 'full', glm_source: 'some-source', glm_content: 'some-content')
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  describe 'with multiple eligible namespaces' do
    let(:eligible_namespaces) do
      [
        build_stubbed(:group),
        build_stubbed(:group, name: 'name', path: 'path'),
        build_stubbed(:group, name: 'name', path: 'path2')
      ]
    end

    let(:expected_form_data_attributes) do
      {
        namespaceData: {
          anyTrialEligibleNamespaces: true,
          initialValue: '1',
          items: [
            {
              text: eligible_namespaces.first.name,
              value: eligible_namespaces.first.id.to_s
            },
            {
              text: 'name (/path)',
              value: eligible_namespaces.second.id.to_s
            },
            {
              text: 'name (/path2)',
              value: eligible_namespaces.third.id.to_s
            }
          ]
        }.merge(extra_namespace_data)
      }.with_indifferent_access
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'has values for the option value attribute' do
      parsed_view_model.dig('namespaceData', 'items').each do |option|
        msg = "Group selector option '#{option['text']}' has non-numeric value '#{option['value']}', " \
          'which could cause issues with form submission'

        expect(option['value']).to match(/^\d+$/), msg
      end
    end
  end

  def parsed_view_model
    actual_element = component.find('#js-create-trial-form')
    data_view_model = actual_element['data-view-model']
    ::Gitlab::Json.parse(data_view_model)
  end

  def expect_form_data_attribute(data_attributes)
    view_model = parsed_view_model

    data_attributes.each do |attribute, value|
      expect(view_model[attribute]).to eq(value)
    end
  end
end
