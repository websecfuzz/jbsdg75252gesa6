# frozen_string_literal: true

module GitlabSubscriptions
  class BaseDiscoverComponent < ViewComponent::Base
    include SafeFormatHelper # used by inheriting classes

    # @param [Namespace or Group] namespace

    def initialize(namespace:)
      @namespace = namespace
    end

    private

    attr_reader :namespace

    delegate :page_title, to: :helpers

    def documentation_link_track_action
      if trial_active?
        "click_documentation_link_#{trial_type}_trial_active"
      else
        "click_documentation_link_#{trial_type}_trial_expired"
      end
    end

    def trial_type
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def trial_active?
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def text_page_title
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def hero_logo
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def hero_header_text
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def hero_tagline_text
      nil
    end

    def buy_now_link
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def cta_button_text
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def hero_video
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def why_section_header_text
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def core_feature_one_header_text
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def core_feature_two_header_text
      nil
    end

    def hero_thumbnail
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def discover_card_collection
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def core_section_one_card_collection
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def core_section_two_card_collection
      []
    end

    def render_footer_link(link_path:, link_text:, track_action:, track_label:)
      link_to(
        link_text, link_path, class: 'gl-link', target: '_blank', rel: 'noopener noreferrer',
        data: {
          track_label: track_label,
          track_action: track_action
        }
      )
    end

    def hand_raise_lead_data
      {
        namespace_id: namespace.id,
        glm_content: glm_content,
        cta_tracking: {
          action: 'click_contact_sales',
          label: trial_status_cta_label
        }.to_json,
        button_attributes: {
          category: buy_now_link ? 'secondary' : 'primary',
          variant: 'confirm',
          class: 'gl-w-full sm:gl-w-auto',
          'data-testid': 'trial-discover-hand-raise-lead-button'
        }.to_json
      }
    end

    def glm_content
      raise NoMethodError, 'This method must be implemented in a subclass'
    end

    def trial_status_cta_label
      if trial_active?
        "#{trial_type}_active_trial"
      else
        "#{trial_type}_expired_trial"
      end
    end

    def core_feature_one_grid_class
      'md:gl-grid-cols-4'
    end

    def core_feature_two_grid_class
      'md:gl-grid-cols-4'
    end
  end
end
