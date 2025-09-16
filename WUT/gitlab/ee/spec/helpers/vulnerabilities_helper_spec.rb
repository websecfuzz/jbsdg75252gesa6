# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VulnerabilitiesHelper, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
  let_it_be_with_refind(:finding) { create(:vulnerabilities_finding, :with_pipeline, :with_cve, :with_token_status, token_status: :active, project: project, severity: :high) }
  let_it_be(:advisory) { create(:pm_advisory, cve: finding.cve_value) }
  let_it_be(:cve_enrichment_object) { create(:pm_cve_enrichment, cve: finding.cve_value) }

  let(:vulnerability) { create(:vulnerability, title: "My vulnerability", project: project, findings: [finding]) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  RSpec.shared_examples 'vulnerability properties' do
    let(:vulnerability_serializer_hash) do
      vulnerability.slice(
        :id,
        :title,
        :state,
        :severity,
        :report_type,
        :resolved_on_default_branch,
        :project_default_branch,
        :resolved_by_id,
        :dismissed_by_id,
        :confirmed_by_id
      )
    end

    let(:finding_serializer_hash) do
      finding.slice(
        :description,
        :identifiers,
        :links,
        :location,
        :name,
        :issue_feedback,
        :project,
        :remediations,
        :solution,
        :uuid,
        :details
      )
    end

    let(:desired_serializer_fields) { %i[metadata identifiers name issue_feedback merge_request_feedback project scanner uuid details dismissal_feedback false_positive state_transitions issue_links merge_request_links] }

    before do
      vulnerability_serializer_stub = instance_double("VulnerabilitySerializer")
      expect(VulnerabilitySerializer).to receive(:new).and_return(vulnerability_serializer_stub)
      expect(vulnerability_serializer_stub).to receive(:represent).with(vulnerability).and_return(vulnerability_serializer_hash)

      finding_serializer_stub = instance_double("Vulnerabilities::FindingSerializer")
      expect(Vulnerabilities::FindingSerializer).to receive(:new).and_return(finding_serializer_stub)
      expect(finding_serializer_stub).to receive(:represent).with(finding, only: desired_serializer_fields).and_return(finding_serializer_hash)
    end

    around do |example|
      freeze_time { example.run }
    end

    it 'has expected vulnerability properties' do
      expect(subject).to include(
        timestamp: Time.now.to_i,
        new_issue_url: "/#{project.full_path}/-/issues/new?vulnerability_id=#{vulnerability.id}",
        create_jira_issue_url: nil,
        related_jira_issues_path: "/#{project.full_path}/-/integrations/jira/issues?state=all&vulnerability_ids%5B%5D=#{vulnerability.id}",
        jira_integration_settings_path: "/#{project.full_path}/-/settings/integrations/jira/edit",
        create_mr_url: "/#{project.full_path}/-/vulnerability_feedback",
        discussions_url: "/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}/discussions",
        notes_url: "/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}/notes",
        related_issues_help_path: kind_of(String),
        pipeline: anything,
        can_modify_related_issues: false
      )
    end

    context 'when the issues are disabled for the project' do
      before do
        allow(project).to receive(:issues_enabled?).and_return(false)
      end

      it 'has `new_issue_url` set as nil' do
        expect(subject).to include(new_issue_url: nil)
      end
    end
  end

  describe '#vulnerability_details_app_data' do
    subject { helper.vulnerability_details_app_data(vulnerability, pipeline, project) }

    let(:jira_integration) do
      create(:jira_integration, project: project, issues_enabled: true, project_key: 'FE', project_keys: %w[FE BE],
        vulnerabilities_enabled: true, vulnerabilities_issuetype: '10001', customize_jira_issue_enabled: false)
    end

    before do
      allow(helper).to receive(:can?).and_return(true)
      allow(vulnerability.project).to receive(:jira_integration).and_return(jira_integration)
      allow(jira_integration).to receive(:new_issue_url_with_predefined_fields).and_return('https://jira.example.com/new')
    end

    it 'returns details app data' do
      expect(subject).to match(
        a_hash_including(
          project_full_path: %r{namespace\d+\/project-\d+},
          commit_path_template: %r{\/namespace\d+\/project-\d+\/\-\/commit\/\$COMMIT_SHA},
          can_view_false_positive: 'false',
          customize_jira_issue_enabled: 'false'
        )
      )
      expect(Gitlab::Json.parse(subject[:vulnerability])['severity']).to eq('high')
    end
  end

  describe '#vulnerability_details' do
    before do
      allow(helper).to receive(:can?).and_return(true)
    end

    subject(:vulnerability_details) { helper.vulnerability_details(vulnerability, pipeline) }

    describe '[:archival_information]' do
      let(:expected_archival_date) { Time.zone.now.beginning_of_month }

      subject { vulnerability_details[:archival_information] }

      before do
        allow(vulnerability).to receive(:about_to_be_archived?).and_return(about_to_be_archived?)
        allow(vulnerability).to receive(:expected_to_be_archived_on).and_return(expected_archival_date)
      end

      context 'when the vulnerability is about to be archived' do
        let(:about_to_be_archived?) { true }

        it { is_expected.to match(about_to_be_archived: true, expected_to_be_archived_on: expected_archival_date) }
      end

      context 'when the vulnerability is not about to be archived' do
        let(:about_to_be_archived?) { false }

        it { is_expected.to match(about_to_be_archived: false, expected_to_be_archived_on: expected_archival_date) }
      end
    end

    describe '[:can_modify_related_issues]' do
      context 'with security dashboard feature enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        context 'when user can manage related issues' do
          before do
            project.add_maintainer(user)
          end

          it { is_expected.to include(can_modify_related_issues: true) }
        end

        context 'when user cannot manage related issues' do
          it { is_expected.to include(can_modify_related_issues: false) }
        end
      end

      context 'with security dashboard feature disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
          project.add_developer(user)
        end

        it { is_expected.to include(can_modify_related_issues: false) }
      end
    end

    describe '[:can_admin]' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when user can admin vulnerabilities' do
        before do
          project.add_maintainer(user)
        end

        it { is_expected.to include(can_admin: true) }
      end

      context 'when user can not admin vulnerabilities' do
        it { is_expected.to include(can_admin: false) }
      end
    end

    context 'when pipeline exists' do
      subject { helper.vulnerability_details(vulnerability, pipeline) }

      include_examples 'vulnerability properties'

      it 'returns expected pipeline data' do
        expect(subject[:pipeline]).to include(
          id: pipeline.id,
          created_at: pipeline.created_at.iso8601,
          url: be_present
        )
      end
    end

    context 'when pipeline is nil' do
      subject { helper.vulnerability_details(vulnerability, nil) }

      include_examples 'vulnerability properties'

      it 'returns no pipeline data' do
        expect(subject[:pipeline]).to be_nil
      end
    end

    context 'dismissal descriptions' do
      let(:expected_descriptions) do
        {
          acceptable_risk: "The vulnerability is known, and has not been remediated or mitigated, but is considered to be an acceptable business risk.",
          false_positive: "An error in reporting in which a test result incorrectly indicates the presence of a vulnerability in a system when the vulnerability is not present.",
          mitigating_control: "A management, operational, or technical control (that is, safeguard or countermeasure) employed by an organization that provides equivalent or comparable protection for an information system.",
          used_in_tests: "The finding is not a vulnerability because it is part of a test or is test data.",
          not_applicable: "The vulnerability is known, and has not been remediated or mitigated, but is considered to be in a part of the application that will not be updated."
        }
      end

      let(:translated_descriptions) do
        # Use dynamic translations via N_(...)
        expected_descriptions.values.map { |description| _(description) }
      end

      it 'includes translated dismissal descriptions' do
        Gitlab::I18n.with_locale(:zh_CN) do
          expect(subject[:dismissal_descriptions].keys).to eq(expected_descriptions.keys)
          expect(subject[:dismissal_descriptions].values).to eq(translated_descriptions)
        end
      end
    end

    describe '[:severity_override]' do
      subject(:severity_override) { vulnerability_details[:severity_override] }

      context 'when there is no severity override for the vulnerability' do
        it { is_expected.to be_nil }
      end

      context 'when there are severity overrides for the vulnerability' do
        let!(:author) { create(:user) }
        let!(:old_severity_override) do
          create(:vulnerability_severity_override, vulnerability: vulnerability, author: author)
        end

        let!(:most_recent_severity_override) do
          create(:vulnerability_severity_override, vulnerability: vulnerability, author: author)
        end

        it 'contains the information from the most recent severity override record' do
          expect(severity_override).to include(
            id: most_recent_severity_override.id,
            new_severity: 'critical',
            original_severity: 'low',
            author: {
              name: author.name,
              web_url: user_path(author)
            }
          )
          expect(severity_override[:created_at]).to be_present
        end
      end
    end

    describe 'ai_resolution_enabled' do
      subject(:ai_resolution_enabled) { vulnerability_details[:ai_resolution_enabled] }

      context 'when vulnerability_read is present' do
        let(:has_vulnerability_resolution) { true }

        before do
          vulnerability.vulnerability_read.update!(has_vulnerability_resolution: has_vulnerability_resolution)
        end

        it { is_expected.to be_truthy }

        context 'when has_vulnerability_resolution is false' do
          let(:has_vulnerability_resolution) { false }

          it { is_expected.to be_falsey }
        end
      end

      context 'when vulnerability_read is not present' do
        before do
          vulnerability.vulnerability_read.destroy!
          vulnerability.reload
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#create_jira_issue_url_for' do
    subject { helper.create_jira_issue_url_for(vulnerability) }

    let(:jira_integration) { double('Integrations::Jira', new_issue_url_with_predefined_fields: 'https://jira.example.com/new') }

    before do
      allow(helper).to receive(:can?).and_return(true)
      allow(vulnerability.project).to receive(:jira_integration).and_return(jira_integration)
    end

    context 'with jira vulnerabilities integration enabled' do
      before do
        allow(project).to receive(:jira_vulnerabilities_integration_enabled?).and_return(true)
        allow(project).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(true)
      end

      context 'when the given object is a vulnerability' do
        let(:expected_jira_issue_description) do
          <<-JIRA.strip_heredoc
            Issue created from vulnerability [#{vulnerability.id}|http://localhost/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}]

            h3. Description:

            Description of My vulnerability

            * Severity: high
            * Location: [maven/src/main/java/com/gitlab/security_products/tests/App.java:29|http://localhost/#{project.full_path}/-/blob/b83d6e391c22777fca1ed3012fce84f633d7fed0/maven/src/main/java/com/gitlab/security_products/tests/App.java#L29]

            #### Evidence

            * Method: `GET`
            * URL: http://goat:8080/WebGoat/logout

            ##### Request:

            ```
            Accept : */*
            ```

            ##### Response:

            ```
            Content-Length : 0
            ```

            ### Solution:

            See vulnerability [#{vulnerability.id}|http://localhost/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}] for any Solution details.

            h3. Identifiers:

            * [CVE-2021-44228|http://cve.mitre.org/cgi-bin/cvename.cgi?name=2018-1234]

            h3. Links:

            * [Cipher does not check for integrity first?|https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first]


            h3. Scanner:

            * Name: Find Security Bugs
          JIRA
        end

        it 'delegates rendering URL to Integrations::Jira' do
          expect(jira_integration).to receive(:new_issue_url_with_predefined_fields).with("Investigate vulnerability: #{vulnerability.title}", expected_jira_issue_description)

          subject
        end

        context 'when scan property is empty' do
          before do
            vulnerability.finding.scan = nil
          end

          it 'renders description using dedicated template without raising error' do
            expect(jira_integration).to receive(:new_issue_url_with_predefined_fields).with("Investigate vulnerability: #{vulnerability.title}", expected_jira_issue_description)

            subject
          end
        end
      end

      context 'when the given object is an unpersisted finding' do
        let(:vulnerability) { build(:vulnerabilities_finding, :with_remediation, project: project) }
        let(:expected_jira_issue_description) do
          <<~TEXT
            h3. Description:

            The cipher does not provide data integrity update 1

            * Severity: high
            * Location: [maven/src/main/java/com/gitlab/security_products/tests/App.java:29|maven/src/main/java/com/gitlab/security_products/tests/App.java:29]


            h3. Links:

            * [Cipher does not check for integrity first?|https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first]


            h3. Scanner:

            * Name: Find Security Bugs
          TEXT
        end

        it 'delegates rendering URL to Integrations::Jira' do
          expect(jira_integration).to receive(:new_issue_url_with_predefined_fields).with("Investigate vulnerability: #{vulnerability.name}", expected_jira_issue_description)

          subject
        end
      end

      context 'when the given object is a Security::Finding' do
        let(:pipeline) { create(:ci_pipeline, project: project) }
        let(:scan) { create(:security_scan, pipeline: pipeline, project: project) }
        let(:vulnerability) { create(:security_finding, :with_finding_data, scan: scan) }
        let(:expected_jira_issue_description) do
          <<~TEXT
            h3. Description:

            The cipher does not provide data integrity update 1

            * Severity: critical

            h3. Identifiers:

            * find_sec_bugs_type-PREDICTABLE_RANDOM
            * [CWE-259|https://cwe.mitre.org/data/definitions/259.html]

            h3. Links:

            * [Cipher does not check for integrity first?|https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first]


            h3. Scanner:

            * Name: Find Security Bugs
            * Type: dast
          TEXT
        end

        it 'delegates rendering URL to Integrations::Jira' do
          expect(jira_integration).to receive(:new_issue_url_with_predefined_fields).with("Investigate vulnerability: #{vulnerability.name}", expected_jira_issue_description)

          subject
        end
      end
    end

    context 'with jira vulnerabilities integration disabled' do
      before do
        allow(project).to receive(:jira_vulnerabilities_integration_enabled?).and_return(false)
        allow(project).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#vulnerability_finding_data' do
    subject { helper.vulnerability_finding_data(vulnerability) }

    it 'returns finding information' do
      expect(subject.to_h).to match(
        description: finding.description,
        description_html: match(%r{p data-sourcepos.*?\<\/p}),
        identifiers: kind_of(Array),
        issue_feedback: anything,
        links: finding.links,
        location: finding.location,
        name: finding.name,
        merge_request_feedback: anything,
        project: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        remediations: finding.remediations,
        solution: kind_of(String),
        solution_html: match(%r{p data-sourcepos.*?\<\/p}),
        evidence: kind_of(String),
        scanner: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        request: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        response: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        evidence_source: anything,
        assets: kind_of(Array),
        supporting_messages: kind_of(Array),
        uuid: kind_of(String),
        details: kind_of(Hash),
        dismissal_feedback: anything,
        state_transitions: kind_of(Array),
        issue_links: kind_of(Array),
        merge_request_links: kind_of(Array),
        ai_explanation_available: finding.ai_explanation_available?,
        ai_resolution_available: finding.ai_resolution_available?,
        belongs_to_public_project: vulnerability.project.public?,
        cve_enrichment: {
          epss_score: cve_enrichment_object.epss_score,
          is_known_exploit: cve_enrichment_object.is_known_exploit
        },
        cvss: [{
          overall_score: advisory.cvss_v3.overall_score,
          version: advisory.cvss_v3.version
        }],
        validity_checks_enabled: be_in([true, false])
      )

      expect(subject[:location]['blob_path']).to match(kind_of(String))
    end

    context 'when there is no CVE enrichment' do
      before do
        allow(finding).to receive(:cve_enrichment).and_return(nil)
      end

      it 'returns nil for cve_enrichment' do
        expect(subject[:cve_enrichment]).to be_nil
      end
    end

    context 'when there is no CVSS data' do
      before do
        allow(finding).to receive(:advisory).and_return(nil)
      end

      it 'returns an empty array for cvss' do
        expect(subject[:cvss]).to eq([])
      end
    end

    context 'when there is no file' do
      before do
        vulnerability.finding.location['file'] = nil
        vulnerability.finding.location.delete('blob_path')
      end

      it 'does not have a blob_path if there is no file' do
        expect(subject[:location]).not_to have_key('blob_path')
      end
    end

    context 'with existing vulnerability_state_transition, issue link and merge request link' do
      let_it_be(:feedback) { create(:vulnerability_feedback, :comment, :dismissal, project: project, pipeline: pipeline, finding_uuid: finding.uuid) }
      let!(:vulnerability_state_transition) { create(:vulnerability_state_transition, vulnerability: vulnerability, to_state: :dismissed, comment: "Dismissal Comment", dismissal_reason: :false_positive) }
      let!(:vulnerabilities_issue_link) { create(:vulnerabilities_issue_link, vulnerability: vulnerability) }
      let!(:vulnerabilities_merge_request_link) { create(:vulnerabilities_merge_request_link, vulnerability: vulnerability) }

      it 'returns finding link associations', :aggregate_failures do
        expect(subject[:state_transitions].first[:comment]).to eq vulnerability_state_transition.comment
        expect(subject[:issue_links].first[:issue_iid]).to eq vulnerabilities_issue_link.issue.iid
        expect(subject[:merge_request_links].first[:merge_request_iid]).to eq vulnerabilities_merge_request_link.merge_request.iid
      end

      # Deprecated information is still returned but should not be used.
      it 'returns dismissal feedback information', :aggregate_failures do
        dismissal_feedback = subject[:dismissal_feedback]
        expect(dismissal_feedback[:dismissal_reason]).to eq(feedback.dismissal_reason)
        expect(dismissal_feedback[:comment_details][:comment]).to eq(feedback.comment)
      end
    end

    context 'with markdown field for description' do
      context 'when vulnerability has no description and finding has description' do
        before do
          vulnerability.description = nil
          vulnerability.finding.description = '# Finding'
        end

        it 'returns finding information' do
          rendered_markdown = '<h1 data-sourcepos="1:1-1:9" dir="auto">&#x000A;<a href="#finding" aria-hidden="true" class="anchor" id="user-content-finding"></a>Finding</h1>'

          expect(subject[:description_html]).to eq(rendered_markdown)
        end
      end

      context 'when vulnerability has description and finding has description' do
        before do
          vulnerability.description = '# Vulnerability'
          vulnerability.finding.description = '# Finding'
        end

        it 'returns finding information' do
          rendered_markdown = '<h1 data-sourcepos="1:1-1:15" dir="auto">&#x000A;<a href="#vulnerability" aria-hidden="true" class="anchor" id="user-content-vulnerability"></a>Vulnerability</h1>'

          expect(subject[:description_html]).to eq(rendered_markdown)
        end
      end
    end

    context 'when validity_checks feature flag is disabled' do
      before do
        stub_feature_flags(validity_checks: false)
      end

      it 'does not include finding_token_status or validity_checks_enabled in the result' do
        expect(subject).not_to include(:finding_token_status)
        expect(subject).not_to include(:validity_checks_enabled)
      end
    end

    context 'when validity_checks feature flag is enabled' do
      before do
        stub_feature_flags(validity_checks: true)
      end

      context 'when validity checks is disabled for the project' do
        before do
          project.security_setting.update!(validity_checks_enabled: false)
        end

        it 'does not include finding_token_status in the result' do
          expect(subject).not_to include(:finding_token_status)
        end
      end

      context 'when validity checks is enabled for the project' do
        before do
          project.security_setting.update!(validity_checks_enabled: true)
        end

        it 'returns finding token status and validity_checks_enabled' do
          expect(subject[:finding_token_status]).to eq(finding.finding_token_status)
          expect(subject[:validity_checks_enabled]).to eq(finding.project.security_setting&.validity_checks_enabled)
        end
      end
    end
  end

  describe '#vulnerability_scan_data?' do
    subject { helper.vulnerability_scan_data?(vulnerability) }

    context 'scanner present' do
      before do
        allow(vulnerability).to receive(:scanner).and_return(true)
      end

      it { is_expected.to be_truthy }
    end

    context 'scan present' do
      before do
        allow(vulnerability).to receive(:scanner).and_return(false)
        allow(vulnerability).to receive(:scan).and_return(true)
      end

      it { is_expected.to be_truthy }
    end

    context 'neither scan nor scanner being present' do
      before do
        allow(vulnerability).to receive(:scanner).and_return(false)
        allow(vulnerability).to receive(:scan).and_return(false)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#vulnerability_representation_information' do
    subject { helper.format_vulnerability_representation_information(vulnerability.representation_information) }

    context 'when there is no vulnerability representation information' do
      before do
        vulnerability.representation_information = nil
      end

      it { is_expected.to be_nil }
    end

    context 'when the vulnerability has representation information' do
      before do
        vulnerability.representation_information = create(:vulnerability_representation_information, vulnerability: vulnerability, project: project, resolved_in_commit_sha: 'abc123def456', created_at: Date.yesterday)
      end

      it 'returns and formats the representation information' do
        expect(subject[:resolved_in_commit_sha]).to eq('abc123def456')
        expect(subject[:resolved_in_commit_sha_link]).to match(%r{\/namespace\d+\/project-\d+\/\-\/commit\/abc123def456})
        expect(subject[:created_at]).to eq(Date.yesterday)
      end
    end

    context 'when the vulnerability has representation information but resolved_in_commit_sha is nil' do
      before do
        vulnerability.representation_information = create(:vulnerability_representation_information, vulnerability: vulnerability, project: project, resolved_in_commit_sha: nil, created_at: Date.yesterday)
      end

      it 'returns the representation information with nil values' do
        expect(subject[:resolved_in_commit_sha]).to be_nil
        expect(subject[:resolved_in_commit_sha_link]).to be_nil
        expect(subject[:created_at]).to eq(Date.yesterday)
      end
    end
  end

  describe '#vulnerabilities_exportable_link' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:url_builder) { Gitlab::UrlBuilder.instance }

    subject(:exportable_link) { helper.vulnerabilities_exportable_link(export) }

    context 'when exportable is a project' do
      let(:project) { build_stubbed(:project) }
      let(:export) { build_stubbed(:vulnerability_export, project: project) }

      it { is_expected.to eq("project <a href=\"#{url_builder.project_url(project)}\">#{project.full_name}</a>") }
    end

    context 'when exportable is a group' do
      let(:group) { build_stubbed(:group) }
      let(:export) { build_stubbed(:vulnerability_export, group: group, project: nil) }

      it { is_expected.to eq("group <a href=\"#{url_builder.group_canonical_url(group)}\">#{group.full_name}</a>") }
    end

    context 'when exportable is invalid' do
      let(:export) { build_stubbed(:vulnerability_export, group: nil, project: nil) }

      it 'raises a NoMethodError' do
        expect { exportable_link }.to raise_error(NoMethodError, /undefined method `full_name'/)
      end
    end
  end
end
