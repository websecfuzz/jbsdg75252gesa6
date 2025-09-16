# frozen_string_literal: true

class Groups::Analytics::ProductivityAnalyticsController < Groups::Analytics::ApplicationController
  layout 'group'

  before_action :load_project
  before_action :build_request_params
  before_action -> {
    check_feature_availability!(:productivity_analytics)
  }

  before_action -> {
    authorize_view_by_action!(:view_productivity_analytics)
  }

  before_action :validate_params, only: :show, if: -> { request.format.json? }

  include IssuableCollections
  include ProductAnalyticsTracking

  track_internal_event :show, name: 'view_productivity_analytics'

  track_event :show,
    name: 'g_analytics_productivity',
    action: 'perform_analytics_usage_action',
    label: 'redis_hll_counters.analytics.analytics_total_unique_counts_monthly',
    destinations: %i[redis_hll snowplow]

  def show
    respond_to do |format|
      format.html
      format.json do
        metric = params.fetch('metric_type', ProductivityAnalytics::DEFAULT_TYPE)

        data = case params['chart_type']
               when 'scatterplot'
                 productivity_analytics.scatterplot_data(type: metric)
               when 'histogram'
                 productivity_analytics.histogram_data(type: metric)
               else
                 include_relations(paginate(productivity_analytics.merge_requests_extended)).map do |merge_request|
                   serializer.represent(merge_request, {}, ProductivityAnalyticsMergeRequestEntity)
                 end
               end

        render json: data, status: :ok
      end
    end
  end

  private

  def paginate(merge_requests)
    merge_requests.page(params[:page]).per(params[:per_page]).tap do |paginated_data|
      response.set_header('X-Per-Page', paginated_data.limit_value.to_s)
      response.set_header('X-Page', paginated_data.current_page.to_s)
      response.set_header('X-Next-Page', paginated_data.next_page.to_s)
      response.set_header('X-Prev-Page', paginated_data.prev_page.to_s)
      response.set_header('X-Total', paginated_data.total_count.to_s)
      response.set_header('X-Total-Pages', paginated_data.total_pages.to_s)
    end
  end

  def serializer
    @serializer ||= BaseSerializer.new(current_user: current_user)
  end

  def finder_type
    ProductivityAnalyticsFinder
  end

  def default_state
    'merged'
  end

  def validate_params
    if @request_params.invalid?
      render(
        json: { message: 'Invalid parameters', errors: @request_params.errors },
        status: :unprocessable_entity
      )
    end
  end

  def build_request_params
    @request_params ||= ::Analytics::ProductivityAnalyticsRequestParams.new(allowed_request_params.merge(group: @group, project: @project))
  end

  def allowed_request_params
    params.permit(
      :merged_after,
      :merged_before,
      :author_username,
      :milestone_title,
      label_name: []
    )
  end

  def productivity_analytics
    @productivity_analytics ||= ProductivityAnalytics.new(merge_requests: finder.execute, sort: params[:sort])
  end

  def include_relations(paginated_mrs)
    # Due to Rails bug: https://github.com/rails/rails/issues/34889 we can't use .includes statement
    # to avoid N+1 call when we load custom columns.
    # So we load relations manually here.
    ActiveRecord::Associations::Preloader.new(
      records: paginated_mrs,
      associations: { author: [], target_project: { namespace: :route } }
    ).call
    paginated_mrs
  end

  def tracking_namespace_source
    @group
  end

  def tracking_project_source
    nil
  end
end
