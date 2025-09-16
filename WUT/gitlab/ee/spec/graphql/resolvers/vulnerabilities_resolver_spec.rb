# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::VulnerabilitiesResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:resolved) { resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user, **extra_context }) }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user, security_dashboard_projects: [project]) }

    let_it_be(:low_vulnerability) do
      create(:vulnerability, :with_finding, :detected, :low, :dast, :with_issue_links, :with_merge_request_links, project: project)
    end

    let_it_be(:critical_vulnerability) do
      create(:vulnerability, :with_finding, :detected, :critical, :sast, resolved_on_default_branch: true, project: project)
        .tap { |v| v.vulnerability_read.update!(has_vulnerability_resolution: true) }
    end

    let_it_be(:high_vulnerability) do
      create(:vulnerability, :with_finding, :dismissed, :high, :container_scanning, project: project)
    end

    let(:current_user) { user }
    let(:params) { {} }
    let(:extra_context) { {} }
    let(:vulnerable) { project }

    context 'when security_dashboard feature is disabled' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it 'returns an empty collection' do
        expect(subject).to be_empty
      end
    end

    shared_examples_for "a resolver with proper association preloading" do
      it "preloads necessary associations" do
        records = resolved.to_a

        expect do
          records.first.project.namespace
          records.first.project.group
          records.first.project.route
          records.first.finding.scanner
          records.first.finding.identifiers
          records.first.vulnerability_read
        end.not_to exceed_query_limit(0)
      end
    end

    context 'when given sort' do
      context 'when sorting descending by severity' do
        let(:params) { { sort: :severity_desc } }

        it { is_expected.to eq([critical_vulnerability, high_vulnerability, low_vulnerability]) }
      end

      context 'when sorting ascending by severity' do
        let(:params) { { sort: :severity_asc } }

        it { is_expected.to eq([low_vulnerability, high_vulnerability, critical_vulnerability]) }
      end

      context 'when sorting param is not provided' do
        let(:params) { {} }

        it { is_expected.to eq([critical_vulnerability, high_vulnerability, low_vulnerability]) }
      end

      context 'when sorting by invalid param' do
        let(:params) { { sort: :invalid } }

        it { is_expected.to eq([critical_vulnerability, high_vulnerability, low_vulnerability]) }
      end
    end

    context 'when given severities' do
      let(:params) { { severity: ['low'] } }

      it 'only returns vulnerabilities of the given severities' do
        is_expected.to contain_exactly(low_vulnerability)
      end
    end

    context 'when given states' do
      let(:params) { { state: ['dismissed'] } }

      it 'only returns vulnerabilities of the given states' do
        is_expected.to contain_exactly(high_vulnerability)
      end

      context 'when dismissal reason and state other than dismissed is given' do
        let(:params) { { state: %w[detected], dismissal_reason: %w[USED_IN_TESTS FALSE_POSITIVE] } }

        let_it_be(:dismissed_vulnerability_1) { create(:vulnerability, :dismissed, project: project) }
        let_it_be(:vulnerability_read_1) { create(:vulnerability_read, :used_in_tests, vulnerability: dismissed_vulnerability_1, project: project) }

        let_it_be(:dismissed_vulnerability_2) { create(:vulnerability, :dismissed, project: project) }
        let_it_be(:vulnerability_read_2) { create(:vulnerability_read, :false_positive, vulnerability: dismissed_vulnerability_2, project: project) }

        it 'returns only dissmissed Vulnerabilities with matching dismissal reason' do
          is_expected.to match_array([low_vulnerability, critical_vulnerability, dismissed_vulnerability_1, dismissed_vulnerability_2])
        end
      end
    end

    context 'when given scanner external IDs' do
      let(:params) { { scanner: [high_vulnerability.finding_scanner_external_id] } }

      it 'only returns vulnerabilities of the given scanner external IDs' do
        is_expected.to contain_exactly(high_vulnerability)
      end
    end

    context 'when given scanner ID' do
      let(:params) { { scanner_id: [GitlabSchema.id_from_object(high_vulnerability.finding.scanner)] } }

      it 'only returns vulnerabilities of the given scanner IDs' do
        is_expected.to contain_exactly(high_vulnerability)
      end
    end

    context 'when given report types' do
      let(:params) { { report_type: %i[dast sast] } }

      it 'only returns vulnerabilities of the given report types' do
        is_expected.to contain_exactly(critical_vulnerability, low_vulnerability)
      end
    end

    context 'when given value for hasIssues argument' do
      let(:params) { { has_issues: has_issues } }

      context 'when has_issues is set to true' do
        let(:has_issues) { true }

        it 'only returns vulnerabilities that have issues' do
          is_expected.to contain_exactly(low_vulnerability)
        end
      end

      context 'when has_issues is set to false' do
        let(:has_issues) { false }

        it 'only returns vulnerabilities that does not have issues' do
          is_expected.to contain_exactly(critical_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given value for hasMergeRequest argument' do
      let(:params) { { has_merge_request: has_merge_request } }

      context 'when has_merge_request is set to true' do
        let(:has_merge_request) { true }

        it 'only returns vulnerabilities that have merge_request' do
          is_expected.to contain_exactly(low_vulnerability)
        end
      end

      context 'when has_issues is set to false' do
        let(:has_merge_request) { false }

        it 'only returns vulnerabilities that does not have merge_request' do
          is_expected.to contain_exactly(critical_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given value for has_resolution argument' do
      let(:params) { { has_resolution: has_resolution } }

      context 'when has_resolution is set to true' do
        let(:has_resolution) { true }

        it 'only returns resolution that have resolution' do
          is_expected.to contain_exactly(critical_vulnerability)
        end
      end

      context 'when has_resolution is set to false' do
        let(:has_resolution) { false }

        it 'only returns resolution that does not have resolution' do
          is_expected.to contain_exactly(low_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given value for has_ai_resolution argument' do
      let(:params) { { has_ai_resolution: has_ai_resolution } }

      context 'when has_ai_resolution is set to true' do
        let(:has_ai_resolution) { true }

        it 'only returns vulnerabilities that are eligible to be resolved by an LLM' do
          is_expected.to contain_exactly(critical_vulnerability)
        end
      end

      context 'when has_ai_resolution is set to false' do
        let(:has_ai_resolution) { false }

        it 'only returns vulnerabilities that are ineligible to be resolved by an LLM' do
          is_expected.to contain_exactly(low_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when given project IDs' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project2) { create(:project, namespace: group) }
      let_it_be(:project2_vulnerability) { create(:vulnerability, :with_read, :with_merge_request_links, project: project2) }

      let(:params) { { project_id: [project2.id] } }
      let(:vulnerable) { group }

      before do
        project.update!(namespace: group)
      end

      it 'only returns vulnerabilities belonging to the given projects' do
        is_expected.to contain_exactly(project2_vulnerability)
      end

      context 'with multiple project IDs' do
        let(:params) { { project_id: [project.id, project2.id] } }

        it 'avoids N+1 queries' do
          control = ActiveRecord::QueryRecorder.new do
            resolve(described_class, obj: vulnerable, args: { project_id: [project2.id] }, ctx: { current_user: current_user })
          end

          expect do
            subject
          end.not_to exceed_query_limit(control)
        end
      end
    end

    context 'when resolving vulnerabilities for a project' do
      it "returns the project's vulnerabilities" do
        is_expected.to contain_exactly(critical_vulnerability, high_vulnerability, low_vulnerability)
      end
    end

    context 'when resolving vulnerabilities for an instance security dashboard' do
      before do
        project.add_developer(user)
      end

      let(:vulnerable) { InstanceSecurityDashboard.new(user, project_ids: [project.id]) }

      context 'when user has valid projects' do
        it "returns vulnerabilities for all projects on the current user's instance security dashboard" do
          is_expected.to contain_exactly(critical_vulnerability, high_vulnerability, low_vulnerability)
        end

        it_behaves_like 'vulnerability filterable', :params
      end

      context 'when user does not have valid projects' do
        let(:user) { create(:user) }
        let(:current_user) { nil }

        it 'returns no vulnerabilities' do
          is_expected.to be_empty
        end
      end

      context 'when filtering vulnerabilities with owasp_top_10_2021', :elastic do
        let(:params) { { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] } }
        let(:error_msg) { "Feature is not supported for InstanceSecurityDashboard" }

        it 'raises an error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, s_(error_msg)) do
            resolved
          end
        end
      end
    end

    context 'when image is given' do
      let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
      let_it_be(:cluster_finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, vulnerability: cluster_vulnerability, project: project) }

      let(:params) { { image: [cluster_finding.location['image']] } }

      it 'only returns vulnerabilities with given image' do
        is_expected.to contain_exactly(cluster_vulnerability)
      end

      context 'when different report_type is given along with image' do
        let(:params) { { report_type: %w[sast], image: [cluster_finding.location['image']] } }

        it 'returns empty list' do
          is_expected.to be_empty
        end
      end
    end

    context 'when cluster_id is given' do
      let_it_be(:cluster_agent) { create(:cluster_agent, project: project) }
      let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
      let_it_be(:cluster_finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, agent_id: cluster_agent.id.to_s, vulnerability: cluster_vulnerability, project: project) }
      let_it_be(:cluster_gid) { ::Gitlab::GlobalId.as_global_id(cluster_finding.location['kubernetes_resource']['cluster_id'].to_i, model_name: 'Clusters::Cluster') }

      let(:params) { { cluster_id: [Gitlab::GlobalId.build(nil, model_name: 'Clusters::Cluster', id: non_existing_record_id)] } }

      it 'ignores the filter and returns unmatching vulnerabilities' do
        is_expected.to include(cluster_vulnerability)
      end
    end

    context 'when cluster_agent_id is given' do
      let_it_be(:cluster_agent) { create(:cluster_agent, project: project) }
      let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
      let_it_be(:cluster_finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, agent_id: cluster_agent.id.to_s, project: project, vulnerability: cluster_vulnerability) }
      let_it_be(:cluster_gid) { ::Gitlab::GlobalId.as_global_id(cluster_finding.location['kubernetes_resource']['agent_id'].to_i, model_name: 'Clusters::Agent') }

      let(:params) { { cluster_agent_id: [cluster_gid] } }

      it 'only returns vulnerabilities with given cluster' do
        is_expected.to contain_exactly(cluster_vulnerability)
      end

      context 'when different report_type is given along with cluster' do
        let(:params) { { report_type: %w[sast], cluster_agent_id: [cluster_gid] } }

        it 'returns empty list' do
          is_expected.to be_empty
        end
      end
    end

    context 'when given value for has_remediations argument' do
      let(:params) { { has_remediations: has_remediations } }
      let_it_be(:vulnerability_read_with_remediations) { create(:vulnerability_read, :with_remediations, project: project) }

      context 'when has_remediations is set to true' do
        let(:has_remediations) { true }

        it 'only returns vulnerabilities that have remediations' do
          is_expected.to contain_exactly(vulnerability_read_with_remediations.vulnerability)
        end
      end

      context 'when has_remediations is set to false' do
        let(:has_remediations) { false }

        it 'only returns vulnerabilities that does not have remediations' do
          is_expected.to contain_exactly(low_vulnerability, critical_vulnerability, high_vulnerability)
        end
      end
    end

    context 'when owasp_top_10 is given' do
      let(:params) { { owasp_top_ten: ['A1:2017-Injection'] } }

      let_it_be(:vuln_read_with_owasp_top_10_first) do
        create(:vulnerability_read, :with_owasp_top_10,
          owasp_top_10: 'A1:2017-Injection', severity: :high, project: project)
      end

      let_it_be(:vuln_read) { create(:vulnerability_read, severity: :medium) }

      it 'only returns vulnerabilities with owasp_top_10' do
        is_expected.to contain_exactly(vuln_read_with_owasp_top_10_first.vulnerability)
      end
    end

    context 'when filtering vulnerabilities with owasp_top_10_2021', :elastic do
      let(:params) do
        { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] }
      end

      let_it_be(:vuln_read_with_owasp_top_10_first) do
        create(:vulnerability_read, :with_owasp_top_10, severity: :high, project: project,
          identifier_names: ['A1:2021-Broken Access Control'])
      end

      let_it_be(:vuln_read_with_owasp_top_10_second) do
        create(:vulnerability_read, :with_owasp_top_10,
          owasp_top_10: 'A1:2021-Broken Access Control', severity: :low, project: project,
          identifier_names: ['A1:2021-Broken Access Control'])
      end

      let_it_be(:vuln_read) { create(:vulnerability_read, severity: :medium) }

      context 'without elasticsearch' do
        before do
          allow(::Search::Elastic::VulnerabilityIndexingHelper).to receive(:vulnerability_indexing_allowed?).and_return(false)
        end

        it_behaves_like 'raises ES errors'
      end

      context 'with advanced_vulnerability_management FF disabled' do
        before do
          allow(::Search::Elastic::VulnerabilityIndexingHelper).to receive(:vulnerability_indexing_allowed?).and_return(true)
          stub_feature_flags(advanced_vulnerability_management: false)
        end

        it_behaves_like 'raises ES errors'
      end

      context 'with elastic search' do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            low_vulnerability.vulnerability_read,
            critical_vulnerability.vulnerability_read,
            high_vulnerability.vulnerability_read,
            vuln_read_with_owasp_top_10_first,
            vuln_read_with_owasp_top_10_second
          )
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it 'only returns vulnerabilities with matching owasp_top_10_2021 values in identifier_names' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

          results = resolved.to_a

          expect(results).to match_array([
            vuln_read_with_owasp_top_10_first,
            vuln_read_with_owasp_top_10_second
          ].map(&:vulnerability))
        end

        it 'avoids N+1 queries', :use_sql_query_cache do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user }).to_a
          end

          create(:vulnerability, :with_findings, project: project)
          .tap { |v| v.vulnerability_read.update!(identifier_names: ['A1:2021-Broken Access Control']) }
          ensure_elasticsearch_index!

          expect do
            resolve(described_class, obj: vulnerable, args: params, ctx: { current_user: current_user }).to_a
          end.not_to exceed_query_limit(control)
        end

        context 'when owasp_top_ten_2021 includes "none" and other values' do
          it_behaves_like 'validates owasp_top_ten_2021 filter', :params
        end

        context 'with reachability as parameter' do
          using RSpec::Parameterized::TableSyntax

          let_it_be(:vuln_read_without_occurrences) do
            [
              low_vulnerability.vulnerability_read,
              critical_vulnerability.vulnerability_read,
              high_vulnerability.vulnerability_read,
              vuln_read_with_owasp_top_10_first,
              vuln_read_with_owasp_top_10_second
            ]
          end

          let_it_be(:vuln_read_in_use) do
            sbom_occurrence_in_use = create(:sbom_occurrence, reachability: :in_use)
            vuln_read = create(:vulnerability_read, report_type: :dependency_scanning, project: project)
            create(:sbom_occurrences_vulnerability, occurrence: sbom_occurrence_in_use, vulnerability: vuln_read.vulnerability)

            vuln_read
          end

          let_it_be(:vuln_read_not_found) do
            sbom_occurrence_not_found = create(:sbom_occurrence, reachability: :not_found)
            vuln_read = create(:vulnerability_read, report_type: :dependency_scanning, project: project)
            create(:sbom_occurrences_vulnerability, occurrence: sbom_occurrence_not_found, vulnerability: vuln_read.vulnerability)

            vuln_read
          end

          before do
            Elastic::ProcessBookkeepingService.track!(
              vuln_read_in_use,
              vuln_read_not_found
            )
            ensure_elasticsearch_index!
          end

          where(:reachability, :expected_result) do
            :in_use | [ref(:vuln_read_in_use)]
            :not_found | [ref(:vuln_read_not_found)]
            :unknown | ref(:vuln_read_without_occurrences)
          end

          with_them do
            let(:params) { { reachability: reachability } }

            it 'only returns vulnerabilities with matching reachability values' do
              expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original

              results = resolved.to_a

              expect(results).to match_array(
                expected_result.map(&:vulnerability))
            end
          end
        end
      end
    end

    context 'when identifer_name is given' do
      let_it_be(:identifier_name) { 'CVE-2024-1234' }

      let_it_be(:vuln_read_with_identifier_name_first) do
        create(:vulnerability_read, :with_identifer_name, identifier_names: [identifier_name], project: project)
      end

      let_it_be(:vuln_read_with_identifier_name_second) do
        create(:vulnerability_read, :with_identifer_name, identifier_names: ['CVE-2024-1235'], project: project)
      end

      let_it_be(:vuln_read) { create(:vulnerability_read, severity: :medium) }

      let(:params) { { identifier_name: identifier_name } }

      shared_examples_for 'when elasticsearch is available', :elastic do
        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            vuln_read_with_identifier_name_first, vuln_read_with_identifier_name_second
          )
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it 'retuns vulnerabilities from elasticsearch' do
          expect(Gitlab::Search::Client).to receive(:execute_search).and_call_original
          results = resolved.to_a

          expect(results).to match_array([vuln_read_with_identifier_name_first].map(&:vulnerability))
        end
      end

      context 'when vulnerable is a project' do
        it 'only returns vulnerabilities with matching identifier_name alone' do
          is_expected.to contain_exactly(vuln_read_with_identifier_name_first.vulnerability)
        end

        it_behaves_like 'when elasticsearch is available'
      end

      context 'when vulnerable is a group' do
        let(:vulnerable) { group }

        context 'when the group has more vulnerabilities than the max' do
          let(:error_msg) { 'Group has more than 20k vulnerabilities.' }
          let(:max) { group.vulnerabilities.count - 1 }

          before do
            stub_const(
              '::Security::GroupIdentifierSearch::MAX_VULNERABILITY_COUNT_GROUP_SUPPORT',
              max
            )

            allow(::Security::ProjectStatistics).to receive(:sum_vulnerability_count_for_group)
                                                      .with(group).and_return(group.vulnerabilities.count)
          end

          it 'raises an error' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError, s_(error_msg)) do
              subject
            end
            expect(::Security::ProjectStatistics).to have_received(:sum_vulnerability_count_for_group).once
          end

          it_behaves_like 'when elasticsearch is available'
        end

        context 'when the group has fewer vulnerabilities than the max' do
          it 'only returns vulnerabilities with matching identifier_name alone' do
            is_expected.to contain_exactly(vuln_read_with_identifier_name_first.vulnerability)
          end
        end

        context 'with access advanced vulnerability management enabled' do
          before do
            allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
          end

          it_behaves_like 'vulnerability filterable', :params
        end
      end
    end

    describe 'before and after cursors' do
      let(:vulnerable) { group }
      let(:cursor) { Base64.urlsafe_encode64({ severity: 'high' }.to_json) }

      before_all do
        project.vulnerability_reads.update_all(traversal_ids: group.traversal_ids)
      end

      context 'when there is `before` cursor' do
        let(:extra_context) { { current_arguments: { before: cursor } } }

        it { is_expected.to match_array([critical_vulnerability, high_vulnerability]) }
      end

      context 'when there is `after` cursor' do
        let(:extra_context) { { current_arguments: { after: cursor } } }

        it { is_expected.to match_array([low_vulnerability, high_vulnerability]) }
      end

      context 'when the given cursor is not Base64 encoded' do
        let(:extra_context) { { current_arguments: { after: 'cursor' } } }

        it 'does not raise an error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when the given cursor does not contain a valid JSON' do
        let(:cursor) { Base64.urlsafe_encode64('{ invalid JSON') }
        let(:extra_context) { { current_arguments: { after: cursor } } }

        it 'does not raise an error' do
          expect { subject }.not_to raise_error
        end
      end
    end

    it_behaves_like 'vulnerability filterable', :params

    describe "association preloading" do
      context "when filtering by postgres" do
        it_behaves_like "a resolver with proper association preloading"
      end

      context "when filtering by elasticsearch", :elastic do
        let(:params) do
          { owasp_top_ten_2021: ['A1:2021-Broken Access Control'] }
        end

        let_it_be(:vuln) do
          create(:vulnerability, :with_findings, project: project)
          .tap { |v| v.vulnerability_read.update!(identifier_names: ['A1:2021-Broken Access Control']) }
        end

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          Elastic::ProcessBookkeepingService.track!(
            vuln.vulnerability_read
          )
          ensure_elasticsearch_index!

          allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
        end

        it_behaves_like "a resolver with proper association preloading"
      end
    end

    describe "ElasticSearch pagination", :elastic do
      let_it_be(:vulnerabilities_with_owasp) do
        [
          { severity: :low, cve: 'CVE-2024-1234' },
          { severity: :medium, cve: 'CVE-2024-5678' },
          { severity: :high, cve: 'CVE-2024-9012' },
          { severity: :critical, cve: 'CVE-2024-3456' }
        ].map do |attrs|
          create(:vulnerability, :with_findings, project: project, severity: attrs[:severity])
            .tap { |v| v.vulnerability_read.update!(identifier_names: [attrs[:cve], 'A01:2021-Broken Access Control']) }
        end
      end

      let_it_be(:vulnerability_1) { vulnerabilities_with_owasp[0] }
      let_it_be(:vulnerability_2) { vulnerabilities_with_owasp[1] }
      let_it_be(:vulnerability_3) { vulnerabilities_with_owasp[2] }
      let_it_be(:vulnerability_4) { vulnerabilities_with_owasp[3] }

      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

        Elastic::ProcessBookkeepingService.track!(
          *vulnerabilities_with_owasp.map(&:vulnerability_read)
        )
        ensure_elasticsearch_index!

        allow(current_user).to receive(:can?).with(:access_advanced_vulnerability_management, vulnerable).and_return(true)
      end

      shared_examples 'elasticsearch pagination behavior' do |sort_order = nil|
        it "returns vulnerabilities in #{sort_order || 'default'} order after the cursor" do
          expect(resolved).to be_a(Search::Elastic::Relation)
          expect(resolved.after(severity, reference_vulnerability.id).first(2)).to eq(expected_vulnerabilities)
        end
      end

      context 'when sorting with pagination using after and first' do
        context 'with ascending sort and pagination' do
          let(:params) { { owasp_top_ten_2021: ['A01:2021-Broken Access Control'], sort: :severity_asc } }
          let(:severity) { Enums::Vulnerability::SEVERITY_LEVELS[:low] }
          let(:reference_vulnerability) { vulnerability_1 }
          let(:expected_vulnerabilities) { [vulnerability_2, vulnerability_3] }
          let(:extra_context) { { current_arguments: { first: 2, after: Base64.urlsafe_encode64([severity, reference_vulnerability.id].to_json) } } }

          it_behaves_like 'elasticsearch pagination behavior', 'ascending severity'
        end

        context 'with descending sort and pagination' do
          let(:params) { { owasp_top_ten_2021: ['A01:2021-Broken Access Control'], sort: :severity_desc } }
          let(:severity) { Enums::Vulnerability::SEVERITY_LEVELS[:critical] }
          let(:reference_vulnerability) { vulnerability_4 }
          let(:expected_vulnerabilities) { [vulnerability_3, vulnerability_2] }
          let(:extra_context) { { current_arguments: { first: 2, after: Base64.urlsafe_encode64([severity, reference_vulnerability.id].to_json) } } }

          it_behaves_like 'elasticsearch pagination behavior', 'descending severity'
        end
      end
    end
  end

  describe 'event tracking' do
    subject(:service_action) { resolve(described_class, obj: vulnerable, ctx: { current_user: user }) }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:proj) { create(:project, namespace: group) }
    let_it_be(:user) { create(:user, security_dashboard_projects: [proj]) }

    let(:event) { 'called_vulnerability_api' }
    let(:category) { described_class.name }

    shared_examples 'tracks events at different levels' do |use_elasticsearch|
      let(:additional_properties) { { label: 'graphql', value: use_elasticsearch ? 1 : 0 } }

      before do
        if use_elasticsearch
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:use_elasticsearch?).and_return(true)
          end
        end
      end

      context 'for Project level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { proj }
          let(:namespace) { group }
          let(:vulnerable) { proj }
        end
      end

      context 'for Group level' do
        it_behaves_like 'internal event tracking' do
          let(:project) { nil }
          let(:namespace) { group }
          let(:vulnerable) { group }
        end
      end

      # Elasticsearch is not supported on InstanceSecurityDashboard.
      unless use_elasticsearch
        context 'for Instance level' do
          it_behaves_like 'internal event tracking' do
            let(:project) { nil }
            let(:namespace) { nil }
            let(:vulnerable) { InstanceSecurityDashboard.new(user, project_ids: [proj.id]) }
          end
        end
      end
    end

    context 'when using postgres' do
      it_behaves_like 'tracks events at different levels', false
    end

    context 'when using elasticsearch' do
      it_behaves_like 'tracks events at different levels', true
    end
  end
end
