# frozen_string_literal: true

module MergeRequests
  class ExternalStatusCheck < ApplicationRecord
    self.table_name = 'external_status_checks'

    include Auditable
    include EachBatch
    include Gitlab::EncryptedAttribute

    attr_encrypted :shared_secret,
      mode: :per_attribute_iv,
      algorithm: 'aes-256-cbc',
      key: :db_key_base_32

    scope :with_api_entity_associations, -> { preload(:protected_branches) }
    scope :applicable_to_branch, ->(branch) do
      includes(:protected_branches)
        .references(:protected_branches)
        .where('protected_branches.id IS NULL OR protected_branches.name = ?', branch)
    end
    scope :for_all_branches, -> { where.missing(:protected_branches) }

    belongs_to :project
    has_and_belongs_to_many :protected_branches,
      after_add: :audit_protected_branch_add, after_remove: :audit_protected_branch_remove
    after_create_commit :audit_creation
    after_destroy_commit :audit_deletion
    validates :external_url, presence: true, uniqueness: { scope: :project_id }, addressable_url: true
    validates :name, uniqueness: { scope: :project_id }, presence: true
    validate :protected_branches_must_belong_to_project_or_group_hierarchy

    def async_execute(data)
      return unless protected_branches.none? || protected_branches.by_name(data[:object_attributes][:target_branch]).any?

      ApprovalRules::ExternalApprovalRulePayloadWorker.perform_async(self.id, payload_data(data))
    end

    def status(merge_request, sha)
      last_response = response_for(merge_request, sha)

      return 'pending' unless last_response

      last_response.status
    end

    def failed?(merge_request)
      status(merge_request, merge_request.diff_head_sha) == 'failed'
    end

    def response_for(merge_request, sha)
      merge_request.status_check_responses.order(id: :desc).find_by(external_status_check: self, sha: sha)
    end

    def to_h
      {
        id: self.id,
        name: self.name,
        external_url: self.external_url
      }
    end

    def audit_protected_branch_add(model)
      message = "Added #{model.class.downcase_humanized_name} #{model.name} to #{self.name} status check"
      message += " and removed all other branches from status check" if protected_branches.count == 1
      push_audit_event(message)
    end

    def audit_creation
      message = "Added #{self.name} status check"
      message += if protected_branches.empty?
                   " with all branches"
                 else
                   " with protected branch(es) #{self.protected_branches_names}"
                 end

      push_audit_event(message)
    end

    def audit_deletion
      push_audit_event("Removed #{self.name} status check")
    end

    def audit_protected_branch_remove(model)
      message = if protected_branches.empty?
                  "Added all branches to #{self.name} status check"
                else
                  "Removed #{model.class.downcase_humanized_name} #{model.name} from #{self.name} status check"
                end

      push_audit_event(message)
    end

    def hmac?
      shared_secret.present?
    end

    private

    def protected_branches_names
      self.protected_branches.pluck(:name).join(', ')
    end

    def payload_data(merge_request_hook_data)
      merge_request_hook_data.merge(external_approval_rule: self.to_h)
    end

    def protected_branches_must_belong_to_project_or_group_hierarchy
      errors.add(:base, 'all protected branches must exist within the project') unless protected_branches.all? { |b| project.all_protected_branches.include?(b) }
    end
  end
end

::MergeRequests::ExternalStatusCheck.prepend_mod
