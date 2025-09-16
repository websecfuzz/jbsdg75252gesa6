# frozen_string_literal: true

module Types
  class PipelineSecurityReportFindingType < BaseObject
    graphql_name 'PipelineSecurityReportFinding'

    description 'Represents vulnerability finding of a security report on the pipeline.'

    authorize :read_security_resource

    expose_permissions Types::PermissionTypes::PipelineSecurityReportFinding

    field :report_type,
      type: VulnerabilityReportTypeEnum,
      null: true,
      description: 'Type of the security report that found the vulnerability finding.'

    field :project,
      type: ::Types::ProjectType,
      null: true,
      description: 'Project on which the vulnerability finding was found.'

    field :description,
      type: GraphQL::Types::String,
      null: true,
      description: 'Description of the vulnerability finding.'

    field :location,
      type: VulnerabilityLocationType,
      null: true,
      description: 'Location metadata for the vulnerability. Its fields depend on the type of security scan that ' \
        'found the vulnerability.'

    field :solution,
      type: GraphQL::Types::String,
      null: true,
      description: "Solution for resolving the security report finding."

    field :state,
      type: VulnerabilityStateEnum,
      null: true,
      description: "Finding status."

    field :details, [::Types::VulnerabilityDetailType],
      null: false,
      resolver: Resolvers::Vulnerabilities::DetailsResolver,
      description: 'Details of the security finding.'

    field :title,
      type: GraphQL::Types::String,
      null: true,
      description: 'Title of the vulnerability finding.', method: :name

    field :severity,
      type: VulnerabilitySeverityEnum,
      null: true,
      description: 'Severity of the vulnerability finding.'

    field :severity_overrides,
      ::Types::Vulnerabilities::SeverityOverrideType.connection_type,
      resolver: Resolvers::SecurityReport::SeverityOverridesResolver,
      null: true, description: "List of severity changes for the vulnerability finding."

    field :false_positive,
      type: GraphQL::Types::Boolean,
      null: true,
      description: 'Indicates whether the vulnerability is a false positive.',
      resolver_method: :false_positive?

    field :links, [::Types::Vulnerabilities::LinkType],
      null: true,
      description: 'List of links associated with the vulnerability.'

    field :assets, [::Types::Vulnerabilities::AssetType],
      null: true,
      description: 'List of assets associated with the vulnerability.'

    field :evidence,
      type: VulnerabilityEvidenceType,
      null: true,
      description: 'Evidence for the vulnerability.'

    field :scanner,
      type: VulnerabilityScannerType,
      null: true,
      description: 'Scanner metadata for the vulnerability.'

    field :identifiers,
      type: [VulnerabilityIdentifierType],
      null: false,
      description: 'Identifiers of the vulnerability finding.'

    field :uuid,
      type: GraphQL::Types::String,
      null: true,
      description: 'UUIDv5 digest based on the vulnerability\'s report type, primary identifier, location, ' \
        'fingerprint, project identifier.'

    field :vulnerability,
      type: VulnerabilityType,
      null: true,
      description: 'Vulnerability related to the security report finding.'

    field :finding_token_status, Types::Vulnerabilities::FindingTokenStatusType,
      null: true,
      description: 'Status of the secret token associated with this vulnerability.',
      resolver: Resolvers::Vulnerabilities::FindingTokenStatusResolver

    field :issue_links,
      type: ::Types::Vulnerability::IssueLinkType.connection_type,
      null: true,
      description: "List of issue links related to the vulnerability."

    field :merge_request, ::Types::MergeRequestType,
      null: true,
      description: 'Merge request that fixes the vulnerability.'

    field :remediations,
      type: [::Types::Vulnerabilities::RemediationType],
      null: true,
      description: 'Remediations of the security report finding.'

    field :dismissed_at,
      type: Types::TimeType,
      null: true,
      extras: [:lookahead],
      description: 'Time of the dismissal of the security report finding.'

    field :dismissed_by,
      type: ::Types::UserType,
      null: true,
      extras: [:lookahead],
      description: 'User who dismissed the security report finding.'

    field :dismissal_reason,
      type: Types::Vulnerabilities::DismissalReasonEnum,
      null: true,
      extras: [:lookahead],
      description: 'Reason for the dismissal of the security report finding.'

    field :state_comment,
      type: GraphQL::Types::String,
      null: true,
      extras: [:lookahead],
      description: 'Comment for the state of the security report finding.'

    field :ai_resolution_available, GraphQL::Types::Boolean,
      null: true,
      description: 'Indicates whether the type of finding can be resolved with AI.',
      method: :ai_resolution_available?

    field :ai_resolution_enabled, GraphQL::Types::Boolean,
      null: true,
      description: 'Indicates whether the specific finding can be resolved with AI.',
      method: :ai_resolution_enabled?

    markdown_field :description_html, null: true

    markdown_field :solution_html, null: true

    def vulnerability
      BatchLoader::GraphQL.for(object.uuid).batch do |uuids, loader|
        ::Vulnerability.with_findings_by_uuid(uuids)
          .with_state_transitions.each do |vulnerability|
          loader.call(vulnerability.finding.uuid, vulnerability)
        end
      end
    end

    def issue_links
      BatchLoader::GraphQL.for(object.uuid).batch do |uuids, loader|
        ::Vulnerability.with_findings_by_uuid(uuids).each do |vulnerability|
          loader.call(vulnerability.finding.uuid, vulnerability.issue_links)
        end
      end
    end

    def merge_request
      BatchLoader::GraphQL.for(object.uuid).batch do |uuids, loader|
        merge_request_via_links(uuids, loader)
      end
    end

    def dismissed_at(lookahead:)
      latest_state_transition(lookahead: lookahead) { |state_transition| state_transition&.created_at }
    end

    def dismissed_by(lookahead:)
      latest_state_transition(lookahead: lookahead) { |state_transition| state_transition&.author }
    end

    def dismissal_reason(lookahead:)
      latest_state_transition(lookahead: lookahead) { |state_transition| state_transition&.dismissal_reason }
    end

    def state_comment(lookahead:)
      latest_state_transition(lookahead: lookahead) { |state_transition| state_transition&.comment }
    end

    def latest_state_transition(lookahead:, &block)
      key = {
        preload_author: lookahead.selects?(:dismissed_by)
      }

      subject = BatchLoader::GraphQL.for(object.uuid).batch(key: key) do |uuids, loader, batch|
        vulnerabilities = ::Vulnerability.with_findings_by_uuid(uuids).with_latest_state_transition
        vulnerabilities = vulnerabilities.preload_transition_author if batch[:key][:preload_author]

        vulnerabilities.each do |vulnerability|
          loader.call(vulnerability.finding.uuid, vulnerability.latest_state_transition_if_dismissed)
        end
      end

      return subject unless block

      ::Gitlab::Graphql::Lazy.with_value(subject, &block)
    end

    def location
      object.location&.merge(
        report_type: object.report_type,
        blob_path: object.present(presenter_class: ::Vulnerabilities::FindingPresenter).blob_path
      )
    end

    def false_positive?
      return unless expose_false_positive?

      object.false_positive?
    end

    def remediations
      object.remediations&.compact || []
    end

    def description_html_resolver
      ::MarkupHelper.markdown(object.description, context.to_h.dup)
    end

    def solution_html_resolver
      ::MarkupHelper.markdown(object.solution, context.to_h.dup)
    end

    private

    def expose_false_positive?
      object.project.licensed_feature_available?(:sast_fp_reduction)
    end

    def merge_request_via_links(uuids, loader)
      ::Vulnerabilities::MergeRequestLink
        .by_finding_uuids(uuids)
        .with_vulnerability_findings
        .with_merge_request
        .each do |link|
          link.vulnerability.findings.each do |finding|
            loader.call(finding.uuid, link.merge_request)
          end
        end
    end
  end
end
