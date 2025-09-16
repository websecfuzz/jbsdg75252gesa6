# frozen_string_literal: true

module API
  class SecurityScans < ::API::Base
    include APIGuard

    # Although this API endpoint responds to POST requests, it is a read-only operation
    allow_access_with_scope :read_api

    SAST_ENDPOINT_REQUIREMENTS = { sast_endpoint: %r{scan} }.freeze

    feature_category :static_application_security_testing

    before { authenticate! }

    helpers do
      def construct_scan_url(endpoint)
        scanner_service_url = ENV.fetch('SCANNER_SERVICE_URL', "#{::CloudConnector::Config.base_url}/sast")
        "#{scanner_service_url}/#{endpoint}"
      end

      def request_headers(token)
        ::CloudConnector.headers(current_user).merge({
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json',
          'User-Agent' => headers['User-Agent']
        })
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Scan a file for vulnerabilities. This feature is experimental.' do
        success code: 200
        failure [
          { code: 400, message: 'Bad request' },
          { code: 401, message: 'Unauthorized' }
        ]
      end
      params do
        requires :file_path, type: String, desc: 'The project relative path of the file to scan'
        requires :content, type: String, desc: 'The content of the file to scan'
      end
      post ':id/security_scans/sast/:sast_endpoint', requirements: SAST_ENDPOINT_REQUIREMENTS do
        unauthorized! unless can?(current_user, :access_security_scans_api, user_project)

        token = CloudConnector::Tokens.get(unit_primitive: :security_scans, resource: user_project)
        unauthorized! if token.nil?

        url = construct_scan_url(params[:sast_endpoint])

        body = declared_params(include_parent_namespaces: false).merge(project_id: params[:id].to_i)

        workhorse_headers =
          Gitlab::Workhorse.send_url(
            url,
            body: Gitlab::Json.dump(body),
            headers: request_headers(token),
            method: "POST",
            timeouts: { read: 55 }
          )

        header(*workhorse_headers)
        status :ok
        body ''
      end
    end
  end
end
