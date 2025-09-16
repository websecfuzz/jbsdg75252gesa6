# frozen_string_literal: true

RSpec.shared_examples GitlabSubscriptions::Trials::DuoPro::LeadFormComponent do
  let(:user) { build(:user) }
  let(:eligible_namespaces) { Group.none }
  let(:submit_path) { '/-/trials/duo_pro?step=lead' }
  let(:namespace_id) { nil }
  let(:kwargs) do
    {
      user: user,
      namespace_id: namespace_id,
      eligible_namespaces: eligible_namespaces,
      submit_path: submit_path
    }.merge(additional_kwargs)
  end

  let(:expected_form_data_attributes) do
    {
      first_name: user.first_name,
      last_name: user.last_name,
      show_name_fields: 'false',
      email_domain: user.email_domain,
      company_name: user.user_detail_organization,
      submit_button_text: 'Continue',
      submit_path: submit_path
    }
  end

  subject { render_inline(described_class.new(**kwargs)) }

  shared_examples 'displays default trial header' do
    it { is_expected.to have_content('Start your free GitLab Duo Pro trial') }
  end

  shared_examples 'renders advantages list' do
    it 'displays check icons for all advantages' do
      expect(page).to have_selector("[data-testid='check-circle-icon']", count: 5)
    end

    it 'displays the regulatory requirements advantage' do
      is_expected.to have_content(
        s_('DuoProTrial|Stay on top of regulatory requirements with self-hosted model deployment')
      )
    end

    it 'displays the data safety advantage' do
      is_expected.to have_content(
        s_('DuoProTrial|Maintain control and keep your data safe')
      )
    end
  end

  context 'with default content' do
    it_behaves_like 'displays default trial header'

    it 'shows trial information form message' do
      is_expected.to have_content(
        s_('DuoProTrial|We just need some additional information to activate your trial.')
      )
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  context 'when user has a blank last name' do
    let(:expected_form_data_attributes) { super().merge(show_name_fields: 'true') }

    before do
      user.last_name = ''
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  context 'with namespace_id' do
    let(:group) { build_stubbed(:group) }
    let(:namespace_id) { group.id }

    context 'when the group is eligible' do
      let(:eligible_namespaces) { [group] }

      before do
        allow(eligible_namespaces).to receive(:find_by_id).with(namespace_id).and_return(group)
      end

      it { is_expected.to have_content("Start your free GitLab Duo Pro trial on #{group.name}") }
    end

    context 'when the group is not eligible' do
      it_behaves_like 'displays default trial header'
    end
  end

  describe 'with eligible namespaces' do
    context 'when single namespace' do
      let(:group) { build_stubbed(:group) }
      let(:eligible_namespaces) { [group] }

      it { is_expected.to have_content("Start your free GitLab Duo Pro trial on #{group.name}") }

      it 'shows activate trial button' do
        expect_form_data_attribute(submit_button_text: 'Activate my trial')
      end
    end

    context 'when multiple namespaces' do
      let(:eligible_namespaces) { build_list(:group, 2) }

      it_behaves_like 'displays default trial header'
    end
  end

  def expect_form_data_attribute(data_attributes)
    data_attributes.each do |attribute, value|
      is_expected.to have_selector("#js-trial-create-lead-form[data-#{attribute.to_s.dasherize}='#{value}']")
    end
  end
end
