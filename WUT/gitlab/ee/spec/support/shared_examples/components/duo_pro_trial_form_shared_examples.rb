# frozen_string_literal: true

RSpec.shared_examples GitlabSubscriptions::Trials::DuoPro::TrialFormComponent do
  let(:eligible_namespaces) { Group.none }
  let(:group1) { build_stubbed(:group, name: 'Test Group 1') }
  let(:group2) { build_stubbed(:group, name: 'Test Group 2') }
  let(:params) do
    ActionController::Parameters.new(
      garbage: 'garbage',
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
    it { is_expected.to have_content('Apply your GitLab Duo Pro trial to an existing group') }
  end

  shared_examples 'renders advantages list' do
    it 'displays the code suggestions advantage' do
      is_expected.to have_content(
        s_('DuoProTrial|Code completion and code generation with Code Suggestions')
      )
    end

    it 'displays the organizational controls advantage' do
      is_expected.to have_content(
        s_('DuoProTrial|Organizational user controls')
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
        s_('DuoProTrial|Apply your GitLab Duo Pro trial to an existing group')
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

    it_behaves_like 'displays default trial header'
    it_behaves_like 'renders advantages list'

    it 'renders correct form header content' do
      is_expected.to have_content(s_('DuoProTrial|Apply your GitLab Duo Pro trial to an existing group'))
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

  private

  def expect_form_data_attribute(data_attributes)
    data_attributes.each do |attribute, value|
      is_expected.to have_selector(".js-namespace-selector[data-#{attribute.to_s.dasherize}='#{value}']")
    end
  end
end
