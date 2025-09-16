# frozen_string_literal: true

class DastSiteValidation < ::SecApplicationRecord
  HEADER = 'Gitlab-On-Demand-DAST'

  belongs_to :dast_site_token
  has_many :dast_sites

  validates :dast_site_token_id, presence: true
  validates :validation_strategy, presence: true

  scope :by_project_id, ->(project_id) do
    joins(:dast_site_token).where(dast_site_tokens: { project_id: project_id })
  end

  scope :by_url_base, ->(url_base) do
    where(url_base: url_base)
  end

  scope :by_most_recent, -> do
    where(id: select('MAX(id) AS id').group(:url_base))
  end

  before_create :set_normalized_url_base

  enum :validation_strategy, { text_file: 0, header: 1, meta_tag: 2 }

  delegate :project, :dast_site, to: :dast_site_token, allow_nil: true

  def validation_url
    "#{url_base}/#{url_path}"
  end

  NONE_STATE = 'none'
  INITIAL_STATE = 'pending'

  state_machine :state, initial: INITIAL_STATE.to_sym do
    event :start do
      transition any => :inprogress
    end

    event :retry do
      transition failed: :inprogress
    end

    event :fail_op do
      transition any - :failed => :failed
    end

    event :pass do
      transition inprogress: :passed
    end

    before_transition pending: :inprogress do |validation|
      validation.validation_started_at = Time.now.utc
    end

    before_transition failed: :inprogress do |validation|
      validation.validation_last_retried_at = Time.now.utc
    end

    before_transition any - :failed => :failed do |validation|
      validation.validation_failed_at = Time.now.utc
    end

    before_transition inprogress: :passed do |validation|
      validation.validation_passed_at = Time.now.utc
    end
  end

  def self.get_normalized_url_base(url)
    uri = Addressable::URI.parse(url)

    "%{scheme}://%{host}:%{port}" % { scheme: uri.scheme, host: uri.host, port: uri.inferred_port }
  end

  private

  def set_normalized_url_base
    self.url_base = self.class.get_normalized_url_base(dast_site_token.url)
  end
end
