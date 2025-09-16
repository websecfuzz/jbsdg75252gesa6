# frozen_string_literal: true

module ProductAnalytics
  class CubeDataQueryService < BaseContainerService
    include Gitlab::Utils::StrongMemoize
    include Analytics::ProductAnalytics::ConfiguratorUrlValidation

    REFRESH_TOKEN_EXPIRE = 1.day

    def execute
      error = cannot_query_data?

      error.nil? ? query_data : error
    end

    def cannot_query_data?
      unless product_analytics_enabled?
        return ServiceResponse.error(message: 'Product Analytics is not enabled', reason: :not_found)
      end

      unless project.connected_to_cluster?
        return ServiceResponse.error(message: 'Access to product analytics is restricted.
          Please consider purchasing product analytics add on or setup your own cluster to continue',
          reason: :unauthorized)
      end

      return ServiceResponse.error(message: 'Access Denied', reason: :unauthorized) unless has_access?

      ServiceResponse.error(message: 'Must provide a url to query', reason: :bad_request) unless params[:path].present?
    end

    private

    def query_data
      options = {
        allow_local_requests: allow_local_requests?,
        headers: cube_security_headers
      }

      begin
        validate_url!(cube_server_url(params[:path]))

        response = if params[:path] == 'meta'
                     Gitlab::HTTP.get(cube_server_url(params[:path]), options)
                   else
                     ::Gitlab::HTTP.post(
                       cube_server_url(params[:path]),
                       options.merge(body: { query: params[:query], queryType: params[:queryType] }.to_json)
                     )
                   end

        body = Gitlab::Json.parse(response.body)
      rescue Gitlab::Json.parser_error, *Gitlab::HTTP::HTTP_ERRORS => e
        return ServiceResponse.error(message: e.message, reason: :bad_gateway)
      end

      if database_missing?(body)
        ServiceResponse.error(message: '404 Clickhouse Database Not Found', reason: :not_found)
      elsif body['error'] == 'Continue wait'
        ServiceResponse.success(message: body['error'], payload: body)
      elsif body['error'].present?
        ServiceResponse.error(message: body['error'], reason: :bad_request)
      elsif params[:path] == 'meta'
        ServiceResponse.success(message: 'Cube Query Successful', payload: body)
      else
        # TODO: Remove the transformer when https://gitlab.com/gitlab-org/gitlab/-/issues/417231
        # is done and cube has been updated
        body['results'] = ::Gitlab::CubeJs::DataTransformer
                             .new(
                               query: params[:query],
                               results: body['results'].deep_dup
                             )
                             .transform
        ServiceResponse.success(message: 'Cube Query Successful', payload: body)
      end
    end

    def product_analytics_enabled?
      Gitlab::CurrentSettings.product_analytics_enabled? &&
        product_analytics_settings.cube_api_base_url.present? &&
        product_analytics_settings.cube_api_key.present? &&
        project.product_analytics_enabled? &&
        !project.personal?
    end

    def has_access?
      can?(current_user, :read_product_analytics, project)
    end

    def cube_server_url(endpoint)
      URI.join(product_analytics_settings.cube_api_base_url, "cubejs-api/v1/", endpoint)
    end

    def gitlab_token
      return unless params[:include_token]

      ::ResourceAccessTokens::CreateService.new(
        current_user,
        project,
        { expires_at: REFRESH_TOKEN_EXPIRE.from_now }).execute.payload[:access_token]&.token
    end

    def cube_security_headers
      payload = {
        iat: Time.now.utc.to_i,
        exp: Time.now.utc.to_i + 180,
        appId: "gitlab_project_#{project.id}",
        gitlabToken: gitlab_token,
        iss: ::Settings.gitlab.host
      }

      {
        "Content-Type": 'application/json',
        Authorization: JWT.encode(payload, product_analytics_settings.cube_api_key, 'HS256')
      }
    end

    def database_missing?(body)
      body['error'] =~ %r{\AError: Code: (81|60)\..*(UNKNOWN_DATABASE|UNKNOWN_TABLE)}
    end

    def product_analytics_settings
      ProductAnalytics::Settings.for_project(project)
    end
    strong_memoize_attr :product_analytics_settings
  end
end
