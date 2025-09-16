# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ExportMailer, feature_category: :vulnerability_management do
  include EmailSpec::Matchers

  describe '#completion_email' do
    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need associations
    let_it_be(:export) { create(:vulnerability_export) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    subject(:email) { described_class.completion_email(export) }

    it 'creates an email notifying of export completion', :aggregate_failures do
      expect(email).to have_subject(s_('Vulnerabilities|Vulnerability report export'))
      expect(email).to have_body_text('The vulnerabilities list was successfully exported for')
      expect(email).to have_body_text(export.project.full_name)
      expect(email).to have_body_text("/#{export.project.full_path}")
      expect(email).to have_body_text(%r{api/v4/security/vulnerability_exports/\d+/download})
      expect(email).to have_body_text(format(s_('Vulnerabilities|This link will expire in %{number} days.'), number: 7))
      expect(email).to be_delivered_to([export.author.notification_email_for(export.project.group)])
    end
  end
end
