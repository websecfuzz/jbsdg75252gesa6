# frozen_string_literal: true

module GitlabSubscriptions
  class DiscoverDuoCoreTrialComponent < BaseDiscoverComponent
    extend ::Gitlab::Utils::Override

    private

    override :trial_type
    def trial_type
      'ultimate'
    end

    override :trial_active?
    def trial_active?
      namespace.ultimate_trial_plan?
    end

    override :discover_card_collection
    def discover_card_collection
      [
        {
          header: s_('DuoCoreTrialDiscover|Unified, secure, and collaborative code management'),
          body: s_(
            "DuoCoreTrialDiscover|Eliminate bottlenecks while meeting security " \
              "requirements with scalable repositories, " \
              "advanced branching, granular access controls, and built-in compliance."
          )
        },
        {
          header: s_('DuoCoreTrialDiscover|Advanced CI/CD'),
          body: s_(
            "DuoCoreTrialDiscover|Prevent pipeline conflicts with merge trains and push rules, " \
              "store build outputs with Artifact Registry, and reuse working templates across teams."
          )
        },
        {
          header: s_('DuoCoreTrialDiscover|Greater developer productivity, collaboration, and quality'),
          body: s_(
            "DuoCoreTrialDiscover|Code from anywhere with remote development workflows, get meaningful feedback " \
              "with Code Review, and track issues effectively with error tracking."
          )
        },
        {
          header: s_('DuoCoreTrialDiscover|Automated compliance'),
          body: s_(
            "DuoCoreTrialDiscover|Free up time to focus on building " \
              "great software with streamlined code reviews, automated security checks, and compliance requirements."
          )
        }
      ]
    end

    override :core_section_one_card_collection
    def core_section_one_card_collection
      [
        {
          header: s_('DuoCoreTrialDiscover|Boost productivity with smart code assistance'),
          body: s_(
            "DuoCoreTrialDiscover|Write secure code faster with AI-powered suggestions in more than 20 languages, " \
              "available in your favorite IDE. Automate routine tasks and accelerate development cycles."
          )
        },
        {
          header: s_('DuoCoreTrialDiscover|Get help from your AI companion throughout development'),
          body: s_(
            "DuoCoreTrialDiscover|Get real-time guidance across the entire software development lifecycle. " \
              "Generate tests, explain code, refactor efficiently, and chat directly in your IDE or web interface."
          )
        },
        {
          header: s_('DuoCoreTrialDiscover|Automate coding and delivery'),
          body: s_(
            "DuoCoreTrialDiscover|Transform your development pipeline " \
              "with intelligent automation tools that handle repetitive tasks."
          )
        },
        {
          header: s_('DuoCoreTrialDiscover|Accelerate learning and collaboration through AI interaction'),
          body: s_(
            "DuoTrialDiscover|Ask questions, explore concepts, " \
              "test ideas, and receive instant feedback directly in your workflow."
          )
        }
      ]
    end

    override :hand_raise_lead_data
    def hand_raise_lead_data
      {
        namespace_id: namespace.id,
        product_interaction: 'SMB Promo',
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

    override :glm_content
    def glm_content
      'trial_discover_page'
    end

    override :text_page_title
    def text_page_title
      s_('DuoCoreTrialDiscover|Discover Premium with Duo Core')
    end

    override :why_section_header_text
    def why_section_header_text
      s_('DuoCoreTrialDiscover|Why GitLab Premium with Duo?')
    end

    override :core_feature_one_header_text
    def core_feature_one_header_text
      s_("DuoCoreTrialDiscover|Native AI Benefits in Premium")
    end

    override :hero_logo
    def hero_logo
      'gitlab/logo.svg'
    end

    override :hero_header_text
    def hero_header_text
      s_(
        'DuoCoreTrialDiscover|GitLab Premium, now with Duo – native AI Code Suggestions and Chat'
      )
    end

    override :hero_tagline_text
    def hero_tagline_text
      safe_join([
        s_(
          'DuoCoreTrialDiscover|New customers can now get access to GitLab Premium with Duo at a discount. ' \
            'Contact Sales to get started.'
        ),
        content_tag(:div, class: 'gl-display-inline-flex gl-items-center gl-gap-2 gl-mb-2') do
          safe_join([
            content_tag(:span, '$29', class: 'gl-text-lg gl-line-through gl-mr-2'),
            content_tag(:span, '$19',
              class: 'gl-text-size-h2-xl gl-font-bold gl-decoration-2 gl-mr-2'),
            content_tag(:span, s_('per user/month'))
          ])
        end
      ])
    end

    override :buy_now_link
    def buy_now_link
      group_billings_path(namespace.root_ancestor)
    end

    override :cta_button_text
    def cta_button_text
      _('Upgrade')
    end

    override :hero_video
    def hero_video
      'https://player.vimeo.com/video/855805049?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=58479'
    end

    override :hero_thumbnail
    def hero_thumbnail
      'duo_pro/video-thumbnail.png'
    end
  end
end
