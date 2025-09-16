# frozen_string_literal: true

module Elastic
  module Latest
    class ApplicationClassProxy < Elasticsearch::Model::Proxy::ClassMethodsProxy
      include ClassProxyUtil
      include Elastic::Latest::Routing
      include Elastic::Latest::QueryContext::Aware

      ADVANCED_QUERY_SYNTAX_REGEX = /[+*"\-|()~\\]/

      def search(query, search_options = {})
        es_options = routing_options(search_options)

        # Counts need to be fast as we load one count per type of document
        # on every page load. Fail early if they are slow since they don't
        # need to be accurate.
        es_options[:timeout] = search_options[:count_only] ? '1s' : '30s'
        es_options[:index] = search_options[:index_name] if search_options[:index_name]

        # Calling elasticsearch-ruby method
        super(query, es_options)
      end

      def es_type
        target.name.underscore
      end

      def es_import(**options)
        transform = ->(r) do
          proxy = r.__elasticsearch__.version(version_namespace)

          { index: { _id: proxy.es_id, data: proxy.as_indexed_json } }.tap do |data|
            data[:index][:routing] = proxy.es_parent if proxy.es_parent
          end
        end

        options[:transform] = transform

        import(options)
      end

      # Should be overriden in *ClassProxy for specific model if data needs to
      # be preloaded by #as_indexed_json method
      def preload_indexing_data(relation)
        relation
      end

      private

      def match_none
        {
          query: { match_none: {} },
          size: 0
        }
      end

      def highlight_options(fields)
        es_fields = fields.map { |field| field.split('^').first }.each_with_object({}) do |field, memo|
          memo[field.to_sym] = {}
        end

        # Adding number_of_fragments: 0 to not split results into snippets.
        # This way controllers can decide how to handle the highlighted data.
        {
          fields: es_fields,
          number_of_fragments: 0,
          pre_tags: [::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG],
          post_tags: [::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG]
        }
      end

      def build_match_phrase_query(options)
        {
          multi_match: {
            _name: context.name(es_type, :multi_match_phrase, :search_terms),
            type: :phrase,
            fields: options[:fields],
            query: options[:query],
            lenient: true
          }
        }
      end

      def build_multi_match_query(options, operator)
        {
          multi_match: {
            _name: context.name(es_type, :multi_match, operator, :search_terms),
            fields: options[:fields],
            query: options[:query],
            operator: operator,
            lenient: true
          }
        }
      end

      def basic_query_hash(fields, query, options = {})
        fields = CustomLanguageAnalyzers.add_custom_analyzers_fields(fields)

        fields = remove_fields_boost(fields) if options[:count_only]

        query_hash =
          if query.present?
            simple_query_string = {
              simple_query_string: {
                _name: context.name(es_type, :match, :search_terms),
                fields: fields,
                query: query,
                lenient: true,
                default_operator: :and
              }
            }

            options[:fields] = fields
            options[:query] = query
            build_query_filter(simple_query_string, options)
          else
            {
              query: {
                bool: {
                  must: { match_all: {} }
                }
              },
              track_scores: true
            }
          end

        if options[:count_only]
          query_hash[:size] = 0
        else
          query_hash[:highlight] = highlight_options(fields)
        end

        query_hash
      end

      def build_query_filter(simple_query_string, options)
        should = []
        must = []

        filter = if options[:no_join_project]
                   []
                 else
                   [
                     {
                       term: {
                         type: {
                           _name: context.name(:doc, :is_a, es_type),
                           value: es_type
                         }
                       }
                     }
                   ]
                 end

        use_match_queries = !query_using_advanced_syntax?(options[:query])

        if options[:count_only] && use_match_queries
          filter << { bool: {
            _name: context.name(:count, es_type, :using_match_queries),
            minimum_should_match: 1,
            should: [
              build_multi_match_query(options, :and),
              build_match_phrase_query(options)
            ]
          } }
        elsif options[:count_only]
          filter << simple_query_string
        elsif use_match_queries
          multi_match_bool = ::Search::Elastic::BoolExpr.new
          multi_match_bool.should << build_multi_match_query(options, :and)
          multi_match_bool.should << build_match_phrase_query(options)
          multi_match_bool.minimum_should_match = 1

          must << { bool: multi_match_bool.to_h }
        else
          must << simple_query_string
        end

        query_hash = {
          query: {
            bool: {
              must: must,
              should: should,
              filter: filter
            }
          }
        }

        query_hash[:query][:bool][:minimum_should_match] = 1 if !should.empty? && use_match_queries

        query_hash
      end

      def query_using_advanced_syntax?(query_string)
        ADVANCED_QUERY_SYNTAX_REGEX.match?(query_string)
      end

      def iid_query_hash(iid)
        {
          query: {
            bool: {
              filter: [
                { term: { iid: { _name: context.name(es_type, :related, :iid), value: iid } } },
                { term: { type: { _name: context.name(:doc, :is_a, es_type), value: es_type } } }
              ]
            }
          }
        }
      end

      def get_query_hash_for_project_and_group_searches(scoped_project_ids, current_user, query_hash, feature)
        context.name(:project) do
          query_hash[:query][:bool][:filter] ||= []
          query_hash[:query][:bool][:filter] << {
            terms: {
              _name: context.name,
              project_id: filter_ids_by_feature(scoped_project_ids, current_user, feature)
            }
          }
        end

        query_hash
      end

      # Builds an elasticsearch query that will select child documents from a
      # set of projects, taking user access rules into account.
      def project_ids_filter(query_hash, options)
        context.name(:project) do
          project_query = project_ids_query(
            options[:current_user],
            options[:project_ids],
            options[:public_and_internal_projects],
            features: options[:features],
            no_join_project: options[:no_join_project],
            project_id_field: options[:project_id_field]
          )

          query_hash[:query][:bool][:filter] ||= []

          query_hash[:query][:bool][:filter] << if options[:no_join_project]
                                                  # Some models have denormalized project permissions into the
                                                  # document so that we do not need to use joins
                                                  project_query[:_name] = context.name
                                                  {
                                                    bool: project_query
                                                  }
                                                else
                                                  {
                                                    has_parent: {
                                                      _name: "#{context.name}:parent",
                                                      parent_type: "project",
                                                      query: {
                                                        bool: project_query
                                                      }
                                                    }
                                                  }
                                                end
        end

        query_hash
      end

      def apply_sort(query_hash, options)
        # Due to different uses of sort param we prefer order_by when
        # present
        case ::Gitlab::Search::SortOptions.sort_and_direction(options[:order_by], options[:sort])
        when :created_at_asc
          query_hash.merge(sort: {
            created_at: {
              order: 'asc'
            }
          })
        when :created_at_desc
          query_hash.merge(sort: {
            created_at: {
              order: 'desc'
            }
          })
        when :updated_at_asc
          query_hash.merge(sort: {
            updated_at: {
              order: 'asc'
            }
          })
        when :updated_at_desc
          query_hash.merge(sort: {
            updated_at: {
              order: 'desc'
            }
          })
        else
          query_hash
        end
      end

      def remove_fields_boost(fields)
        fields.map { |m| m.split('^').first }
      end

      def archived_filter(query_hash)
        archived_false_query = { bool: { filter: { term: { archived: { value: false } } } } }
        archived_missing_query = { bool: { must_not: { exists: { field: 'archived' } } } }
        exclude_archived_query = { bool: { _name: context.name(:non_archived),
                                           should: [archived_false_query, archived_missing_query] } }
        query_hash[:query][:bool] ||= {}
        query_hash[:query][:bool][:filter] ||= []
        query_hash[:query][:bool][:filter] << exclude_archived_query

        query_hash
      end

      # Builds an elasticsearch query that will select projects the user is
      # granted access to.
      #
      # If a project feature(s) is specified, it indicates interest in child
      # documents gated by that project feature - e.g., "issues". The feature's
      # visibility level must be taken into account.
      def project_ids_query(
        user, project_ids, public_and_internal_projects, features: nil,
        no_join_project: false, project_id_field: nil)
        scoped_project_ids = scoped_project_ids(user, project_ids)

        # At least one condition must be present, so pick no projects for
        # anonymous users.
        # Pick private, internal and public projects the user is a member of.
        # Pick all private projects for admins & auditors.
        conditions = pick_projects_by_membership(
          scoped_project_ids,
          user, no_join_project,
          features: features,
          project_id_field: project_id_field
        )

        if public_and_internal_projects
          context.name(:visibility) do
            # Skip internal projects for anonymous and external users.
            # Others are given access to all internal projects.
            #
            # Admins & auditors get access to internal projects even
            # if the feature is private.
            conditions += pick_projects_by_visibility(Project::INTERNAL, user, features) if user && !user.external?

            # All users, including anonymous, can access public projects.
            # Admins & auditors get access to public projects where the feature is
            # private.
            conditions += pick_projects_by_visibility(Project::PUBLIC, user, features)
          end
        end

        { should: conditions }
      end

      # Most users come with a list of projects they are members of, which may
      # be a mix of public, internal or private. Grant access to them all, as
      # long as the project feature is not disabled.
      #
      # Admins & auditors are given access to all private projects. Access to
      # internal or public projects where the project feature is private is not
      # granted here.
      def pick_projects_by_membership(project_ids, user, no_join_project, features: nil, project_id_field: nil)
        # This method is used to construct a query on the join as well as query
        # on top level doc. When querying top level doc the project's ID is
        # used from project_id_field with the default value of `project_id`
        # When joining it is just `id`.
        id_field = if no_join_project
                     project_id_field || :project_id
                   else
                     :id
                   end

        if features.nil?
          if project_ids == :any
            return [{ term: { visibility_level: { _name: context.name(:any), value: Project::PRIVATE } } }]
          end

          return [{ terms: { _name: context.name(:membership, :id), id_field => project_ids } }]
        end

        Array(features).map do |feature|
          condition =
            if project_ids == :any
              { term: { visibility_level: { _name: context.name(:any), value: Project::PRIVATE } } }
            else
              {
                terms: {
                  _name: context.name(:membership, :id),
                  id_field => filter_ids_by_feature(project_ids, user, feature)
                }
              }
            end

          limit = {
            terms: {
              _name: context.name(feature, :enabled_or_private),
              "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
            }
          }

          {
            bool: {
              filter: [condition, limit]
            }
          }
        end
      end

      # Grant access to projects of the specified visibility level to the user.
      #
      # If a project feature is specified, access is only granted if the feature
      # is enabled or, for admins & auditors, private.
      def pick_projects_by_visibility(visibility, user, features)
        context.name(visibility) do
          condition = { term: { visibility_level: { _name: context.name, value: visibility } } }

          limit_by_feature(condition, features, include_members_only: user&.can_read_all_resources?)
        end
      end

      # Useful when performing group searches by traversal_id to prevent
      # access to projects in the group hierarchy that the user does not have
      # permission to view.
      def rejected_project_filter(namespaces, options)
        current_user = options[:current_user]
        scoped_project_ids = scoped_project_ids(current_user, options[:project_ids])
        return {} if scoped_project_ids == :any

        project_ids = filter_ids_by_feature(scoped_project_ids, current_user, options[:features])
        rejected_ids = namespaces.flat_map do |namespace|
          namespace.all_project_ids_except(project_ids).pluck_primary_key
        end

        {
          terms: {
            _name: context.name,
            project_id: rejected_ids
          }
        }
      end

      # If a project feature(s) is specified, access is dependent on its visibility
      # level being enabled (or private if `include_members_only: true`).
      #
      # This method is a no-op if no project feature is specified.
      # It accepts an array of features or a single feature, when an array is provided
      # it queries if any of the features is enabled.
      #
      # Always denies access to projects when the features are disabled - even to
      # admins & auditors - as stale child documents may be present.
      def limit_by_feature(condition, features, include_members_only:)
        return [condition] unless features

        features = Array(features)

        features.map do |feature|
          context.name(feature, :access_level) do
            limit =
              if include_members_only
                {
                  terms: {
                    _name: context.name(:enabled_or_private),
                    "#{feature}_access_level" => [::ProjectFeature::ENABLED, ::ProjectFeature::PRIVATE]
                  }
                }
              else
                {
                  term: {
                    "#{feature}_access_level" => {
                      _name: context.name(:enabled),
                      value: ::ProjectFeature::ENABLED
                    }
                  }
                }
              end

            {
              bool: {
                _name: context.name,
                filter: [condition, limit]
              }
            }
          end
        end
      end

      def filter_ids_by_feature(project_ids, user, feature)
        Project
          .id_in(project_ids)
          .filter_by_feature_visibility(feature, user)
          .pluck_primary_key
      end

      def scoped_project_ids(current_user, project_ids)
        return :any if project_ids == :any

        project_ids ||= []

        # When reading cross project is not allowed, only allow searching a
        # a single project, so the `:read_*` ability is only checked once.
        return [] if !Ability.allowed?(current_user, :read_cross_project) && project_ids.size > 1

        project_ids
      end

      def should_use_project_ids_filter?(options)
        options[:project_ids] == :any || options[:group_ids].blank?
      end

      def authorized_project_ids(current_user, options = {})
        return [] unless current_user

        scoped_project_ids = scoped_project_ids(current_user, options[:project_ids])
        authorized_project_ids = current_user.authorized_projects(Gitlab::Access::REPORTER).pluck_primary_key.to_set

        # if the current search is limited to a subset of projects, we should do
        # confidentiality check for these projects.
        authorized_project_ids &= scoped_project_ids.to_set unless scoped_project_ids == :any

        authorized_project_ids.to_a
      end

      def authorized_namespace_ids(current_user, options = {})
        return [] unless current_user && options[:group_ids].present?

        authorized_ids = current_user.authorized_groups.pluck_primary_key.to_set
        authorized_ids.intersection(options[:group_ids].to_set).to_a
      end

      def traversal_ids_filter(query_hash, namespaces, options)
        namespace_ancestry = namespaces.map(&:elastic_namespace_ancestry)

        context.name(:reject_projects) do
          query_hash[:query][:bool][:must_not] ||= []
          query_hash[:query][:bool][:must_not] << rejected_project_filter(namespaces, options)
        end

        traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
      end

      def traversal_ids_ancestry_filter(query_hash, namespace_ancestry, options)
        context.name(:namespace) do
          query_hash[:query][:bool][:filter] ||= []
          query_hash = add_filter(query_hash, :query, :bool, :filter) do
            ancestry_filter(options[:current_user],
              namespace_ancestry,
              prefix: options.fetch(:traversal_ids_prefix, :traversal_ids)
            )
          end
        end
        query_hash
      end

      def authorization_filter(query_hash, options)
        return project_ids_filter(query_hash, options) if should_use_project_ids_filter?(options)

        namespaces = Namespace.find(authorized_namespace_ids(options[:current_user], options))

        return project_ids_filter(query_hash, options) if namespaces.blank?

        traversal_ids_filter(query_hash, namespaces, options)
      end

      def ancestry_filter(current_user, namespace_ancestry, prefix:)
        return {} unless current_user
        return {} if namespace_ancestry.blank?

        context.name(:ancestry_filter) do
          filters = namespace_ancestry.map do |namespace_ids|
            {
              prefix: {
                "#{prefix}": {
                  _name: context.name(:descendants),
                  value: namespace_ids
                }
              }
            }
          end

          {
            bool: {
              should: filters
            }
          }
        end
      end

      # This is a helper method that we are using to add filter conditions
      # in this method we are skipping all blank hashes and we can use it for adding nested filter conditions.
      # `path` is a sequence of key objects (Hash#dig syntax). The value by that path should be an array.
      def add_filter(query_hash, *path)
        filter_result = yield

        return query_hash if filter_result.blank?

        query_hash.dig(*path) << filter_result
        query_hash
      end

      def apply_simple_query_string(name:, fields:, query:, bool_expr:, count_only:)
        path = if count_only
                 fields = remove_fields_boost(fields)
                 :filter
               else
                 :must
               end

        simple_query_string = {
          simple_query_string: {
            _name: name,
            fields: fields,
            query: query,
            default_operator: :and
          }
        }
        add_filter(bool_expr, path) { simple_query_string }
      end
    end
  end
end
