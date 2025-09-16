# frozen_string_literal: true

class Groups::Analytics::CiCdAnalyticsController < Groups::Analytics::ApplicationController
  include ProductAnalyticsTracking

  layout 'group'

  before_action -> { check_feature_availability!(:group_ci_cd_analytics) }
  before_action -> { authorize_view_by_action!(:view_group_ci_cd_analytics) }

  before_action only: [:show] do
    push_frontend_feature_flag(:dora_metrics_dashboard, @group)
  end

  track_event :show,
    name: 'g_analytics_ci_cd_release_statistics',
    conditions: -> { should_track_ci_cd_release_statistics? }
  track_event :show,
    name: 'g_analytics_ci_cd_deployment_frequency',
    conditions: -> { should_track_ci_cd_deployment_frequency? }
  track_event :show,
    name: 'g_analytics_ci_cd_lead_time',
    conditions: -> { should_track_ci_cd_lead_time? }
  track_event :show,
    name: 'g_analytics_ci_cd_time_to_restore_service',
    conditions: -> { should_track_visit_ci_cd_time_to_restore_service_tab? }
  track_event :show,
    name: 'g_analytics_ci_cd_change_failure_rate',
    conditions: -> { should_track_visit_ci_cd_change_failure_tab? }

  def show; end

  def should_track_ci_cd_release_statistics?
    params[:tab].blank? || params[:tab] == 'release-statistics'
  end

  def should_track_ci_cd_deployment_frequency?
    params[:tab] == 'deployment-frequency'
  end

  def should_track_ci_cd_lead_time?
    params[:tab] == 'lead-time'
  end

  def should_track_visit_ci_cd_time_to_restore_service_tab?
    params[:tab] == 'time-to-restore-service'
  end

  def should_track_visit_ci_cd_change_failure_tab?
    params[:tab] == 'change-failure-rate'
  end
end
