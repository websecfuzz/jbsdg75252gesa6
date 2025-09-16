# frozen_string_literal: true

module Gitlab
  module Search
    module Zoekt
      class Client # rubocop:disable Search/NamespacedClass
        include ::Gitlab::Loggable

        CONTEXT_LINES_COUNT = 1
        PROXY_SEARCH_PATH = '/webserver/api/v2/search'
        JWT_HEADER = 'Gitlab-Zoekt-Api-Request'

        class << self
          def instance
            @instance ||= new
          end

          delegate :search, :search_zoekt_proxy, to: :instance
        end

        def search(query, num:, project_ids:, node_id:, search_mode:, source: nil)
          start = Time.current

          # Safety net because Zoekt will match all projects if you provide an empty array.
          raise 'Not possible to search without at least one project specified' if project_ids.blank?
          raise 'Global search is not supported' if project_ids == :any

          payload = build_search_payload(
            query, source: source, num: num, search_mode: search_mode, project_ids: project_ids
          )

          path = '/api/search'
          target_node = node(node_id)
          raise 'Node can not be found' unless target_node

          response = post_request(join_url(target_node.search_base_url, path), payload)

          log_error('Zoekt search failed', status: response.code, response: response.body) unless response.success?

          Gitlab::Search::Zoekt::Response.new parse_response(response)
        ensure
          add_request_details(start_time: start, path: path, body: payload)
        end

        def search_zoekt_proxy(query, num:, targets:, search_mode:, source: nil, current_user: nil)
          start = Time.current
          if use_ast_search_payload?(current_user)
            payload = ::Search::Zoekt::SearchRequest.new(
              query: format_query(query, source: source, search_mode: search_mode),
              targets: targets,
              num_context_lines: CONTEXT_LINES_COUNT,
              max_line_match_results: num
            ).as_json
          else
            payload = build_search_payload(query, source: source, num: num, search_mode: search_mode)
            payload[:ForwardTo] = targets.map do |node_id, project_ids|
              target_node = node(node_id)
              { Endpoint: target_node.search_base_url, RepoIds: project_ids }
            end
          end

          # Unless a node is specified, prefer the node with the most projects
          node_id ||= targets.max_by { |_zkt_node_id, project_ids| project_ids.length }.first
          proxy_node = node(node_id)
          raise 'Node can not be found' unless proxy_node

          response = post_request(join_url(proxy_node.search_base_url, PROXY_SEARCH_PATH), payload)
          log_error('Zoekt search failed', status: response.code, response: response.body) unless response.success?
          Gitlab::Search::Zoekt::Response.new parse_response(response)
        ensure
          add_request_details(start_time: start, path: PROXY_SEARCH_PATH, body: payload)
        end

        private

        def post_request(url, payload = {}, **options)
          defaults = {
            headers: request_headers,
            body: payload.to_json,
            allow_local_requests: true,
            basic_auth: basic_auth_params
          }

          log_debug('Zoekt HTTP post request', url: url, payload: payload) if debug?

          ::Gitlab::HTTP.post(url, defaults.merge(options))
        rescue *Gitlab::HTTP::HTTP_ERRORS => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
        end

        def request_headers
          {
            'Content-Type' => 'application/json',
            JWT_HEADER => ::Search::Zoekt::JwtAuth.authorization_header
          }
        end

        def basic_auth_params
          @basic_auth_params ||= {
            username: username,
            password: password
          }.compact
        end

        def build_search_payload(query, num:, search_mode:, source:, project_ids: nil)
          {
            Q: format_query(query, source: source, search_mode: search_mode),
            Opts: {
              TotalMaxMatchCount: num,
              NumContextLines: CONTEXT_LINES_COUNT
            }
          }.tap do |payload|
            payload[:RepoIds] = project_ids if project_ids.present?
          end
        end

        def node(node_id)
          ::Search::Zoekt::Node.find_by_id(node_id)
        end

        def join_url(base_url, path)
          # We can't use URI.join because it doesn't work properly with something like
          # URI.join('http://example.com/api', 'index') => #<URI::HTTP http://example.com/index>
          url = [base_url, path].join('/')
          url.gsub(%r{(?<!:)/+}, '/') # Remove duplicate slashes
        end

        def parse_response(response)
          json_response = ::Gitlab::Json.parse(response.body).with_indifferent_access
          log_debug('Zoekt HTTP response', data: json_response) if debug?

          json_response
        rescue Gitlab::Json.parser_error => e
          logger.error(message: e.message)
          raise ::Search::Zoekt::Errors::ClientConnectionError, e.message
        end

        def add_request_details(start_time:, path:, body:)
          return unless ::Gitlab::SafeRequestStore.active?

          duration = (Time.current - start_time)

          ::Gitlab::Instrumentation::Zoekt.increment_request_count
          ::Gitlab::Instrumentation::Zoekt.add_duration(duration)

          ::Gitlab::Instrumentation::Zoekt.add_call_details(
            duration: duration,
            method: 'POST',
            path: path,
            body: body
          )
        end

        def username
          @username ||= File.exist?(username_file) ? File.read(username_file).chomp : nil
        end

        def password
          @password ||= File.exist?(password_file) ? File.read(password_file).chomp : nil
        end

        def username_file
          Gitlab.config.zoekt.username_file
        end

        def password_file
          Gitlab.config.zoekt.password_file
        end

        def logger
          @logger ||= ::Search::Zoekt::Logger.build
        end

        def log_error(message, payload = {})
          logger.error(build_structured_payload(**payload.merge(message: message)))
        end

        def log_debug(message, payload = {})
          logger.debug(build_structured_payload(**payload.merge(message: message)))
        end

        def debug?
          Gitlab.dev_or_test_env? && Gitlab::Utils.to_boolean(ENV['ZOEKT_CLIENT_DEBUG'])
        end

        def format_query(query, source:, search_mode:)
          ::Search::Zoekt::Query.new(query, source: source).formatted_query(search_mode)
        end

        def use_ast_search_payload?(current_user)
          Feature.enabled?(:zoekt_ast_search_payload, current_user)
        end
      end
    end
  end
end
