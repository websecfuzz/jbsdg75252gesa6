# frozen_string_literal: true

module Sidebars
  class MenuItem
    include ::Sidebars::Concerns::LinkWithHtmlOptions

    attr_reader :title, :link, :active_routes, :item_id, :container_html_options, :sprite_icon,
      :sprite_icon_html_options, :has_pill, :pill_count, :pill_count_field, :pill_count_dynamic, :super_sidebar_parent,
      :avatar, :entity_id
    attr_accessor :render
    alias_method :has_pill?, :has_pill

    # rubocop: disable Metrics/ParameterLists
    def initialize(
      title:, link:, active_routes:, item_id: nil, container_html_options: {}, sprite_icon: nil,
      sprite_icon_html_options: {}, has_pill: false, pill_count_dynamic: false, pill_count: nil,
      pill_count_field: nil, super_sidebar_parent: nil, avatar: nil, entity_id: nil
    )
      @title = title
      @link = link
      @active_routes = active_routes
      @item_id = item_id
      @container_html_options = { aria: { label: title } }.merge(container_html_options)
      @sprite_icon = sprite_icon
      @sprite_icon_html_options = sprite_icon_html_options
      @avatar = avatar
      @entity_id = entity_id
      @has_pill = has_pill
      @pill_count = pill_count
      @pill_count_field = pill_count_field
      @pill_count_dynamic = pill_count_dynamic
      @super_sidebar_parent = super_sidebar_parent
    end
    # rubocop: enable Metrics/ParameterLists

    def render?
      return true if @render.nil?

      @render
    end

    def serialize_for_super_sidebar
      {
        id: item_id,
        title: title,
        icon: sprite_icon,
        avatar: avatar,
        entity_id: entity_id,
        link: link,
        active_routes: active_routes,
        link_classes: container_html_options[:class]
        # Check whether support is needed for the following properties,
        # in order to get feature parity with the HAML renderer
        # https://gitlab.com/gitlab-org/gitlab/-/issues/391864
        #
        # container_html_options
      }.merge(pill_attributes).compact
    end

    def pill_attributes
      return {} unless has_pill?

      {
        pill_count: pill_count,
        pill_count_field: pill_count_field,
        pill_count_dynamic: pill_count_dynamic
      }
    end
  end
end
