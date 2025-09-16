# frozen_string_literal: true

RSpec.shared_examples GitlabSubscriptions::Trials::DuoEnterprise::TrialFormComponent do
  let(:eligible_namespaces) { Group.none }
  let(:group1) { build_stubbed(:group, name: 'Test Group 1') }
  let(:group2) { build_stubbed(:group, name: 'Test Group 2') }

  let(:params) do
    ActionController::Parameters.new(
      garbage: 'garbage',
      step: 'trial',
      namespace_id: 2
    )
  end

  let(:kwargs) do
    {
      eligible_namespaces: eligible_namespaces,
      params: params,
      errors: []
    }.merge(additional_kwargs)
  end

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  shared_examples 'displays default trial header' do
    it { is_expected.to have_content('Apply your GitLab Duo Enterprise trial to an existing group') }
  end

  shared_examples 'renders advantages list' do
    it 'displays check icons for all advantages' do
      expect(page).to have_selector("[data-testid='check-circle-icon']", count: 5)
    end

    it 'displays the regulatory requirements advantage' do
      is_expected.to have_content(
        s_('DuoEnterpriseTrial|Stay on top of regulatory requirements with self-hosted model deployment')
      )
    end

    it 'displays the data safety advantage' do
      is_expected.to have_content(
        s_('DuoEnterpriseTrial|Maintain control and keep your data safe')
      )
    end
  end

  context 'with no eligible namespaces' do
    let(:expected_data_attributes) do
      {
        initial_value: 2,
        any_trial_eligible_namespaces: 'false',
        items: eligible_namespaces.to_json
      }
    end

    it_behaves_like 'displays default trial header'

    it 'shows trial information form message' do
      is_expected.to have_content(
        s_('DuoEnterpriseTrial|Apply your GitLab Duo Enterprise trial to an existing group')
      )
    end

    it 'has activation button' do
      is_expected.to have_content('Activate my trial')
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_data_attributes)
    end
  end

  describe 'with eligible namespaces' do
    let(:eligible_namespaces) do
      [
        build_stubbed(:group),
        build_stubbed(:group, name: 'name', path: 'path'),
        build_stubbed(:group, name: 'name', path: 'path2')
      ]
    end

    let(:expected_form_data_attributes) do
      {
        initial_value: 2,
        any_trial_eligible_namespaces: 'true',
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
        ].to_json
      }
    end

    it 'renders correct form header content' do
      is_expected.to have_content(s_('DuoEnterpriseTrial|Apply your GitLab Duo Enterprise trial to an existing group'))
    end

    it { is_expected.to have_content(_('Activate my trial')) }

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end

    it 'has values for the option value attribute' do
      element = component.find('.js-namespace-selector')
      items = ::Gitlab::Json.parse(element['data-items'])

      items.each do |option|
        msg = "Group selector option '#{option['text']}' has non-numeric value '#{option['value']}', " \
          "which could cause issues with form submission"

        expect(option['value']).to match(/^\d+$/), msg
      end
    end
  end

  def expect_form_data_attribute(data_attributes)
    data_attributes.each do |attribute, value|
      is_expected.to have_selector(".js-namespace-selector[data-#{attribute.to_s.dasherize}='#{value}']")
    end
  end
end
