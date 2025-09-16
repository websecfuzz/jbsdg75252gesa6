# frozen_string_literal: true

module AuditEvents
  module Changes
    # Records an audit event in DB for model changes
    #
    # @param [Symbol] column column name to be audited
    # @param [Hash] options the options to create an event with
    # @option options [Symbol] :column column name to be audited
    # @option options [User, Project, Group] :target_model scope the event belongs to
    # @option options [Object] :model object being audited
    # @option options [Boolean] :skip_changes whether to record from/to values
    # @option options [String] :event_type adds event type in streaming audit event headers and payload
    # @return [AuditEvent, nil] the resulting object or nil if there is no
    #   change detected
    def audit_changes(column, options = {})
      column = options[:column] || column
      # rubocop:disable Gitlab/ModuleWithInstanceVariables
      @entity = options[:entity]
      @model = options[:model]
      # rubocop:enable Gitlab/ModuleWithInstanceVariables

      return unless audit_required?(column)

      audit_event(parse_options(column, options))
    end

    protected

    def entity
      @entity || model # rubocop:disable Gitlab/ModuleWithInstanceVariables
    end

    def model
      @model
    end

    private

    def audit_required?(column)
      not_recently_created? && changed?(column)
    end

    def not_recently_created?
      !model.previous_changes.has_key?(:id)
    end

    def changed?(column)
      model.previous_changes.has_key?(column)
    end

    def changes(column)
      model.previous_changes[column]
    end

    def parse_options(column, options)
      options.tap do |options_hash|
        options_hash[:column] = column
        options_hash[:action] = :update

        unless options[:skip_changes]
          options_hash[:from] = changes(column).first
          options_hash[:to] = changes(column).last
        end
      end
    end

    def audit_event(options)
      filter_sensitive_column_values!(options)

      name = options.fetch(:event_type, 'audit_operation')
      details = additional_details(options)
      audit_context = {
        name: name,
        author: @current_user.nil? && respond_to?(:current_user) ? current_user : @current_user, # rubocop:disable Gitlab/ModuleWithInstanceVariables
        scope: entity,
        target: model,
        message: build_message(details),
        additional_details: details,
        target_details: options[:target_details]
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    def filter_sensitive_column_values!(options)
      return unless options[:from] || options[:to]
      return unless model
      return unless model.class.sensitive_attributes.include?(options[:column].to_sym)

      Gitlab::AppJsonLogger.warn(
        class: model.class.name,
        column: options[:column],
        message: "Sensitive column `#{options[:column]}`, removing values from audit log"
      )

      options[:from] = nil
      options[:to] = nil
    end

    def additional_details(options)
      { change: options[:as] || options[:column] }.merge(options.slice(:from, :to, :target_details))
    end

    def build_message(details)
      message = ["Changed #{details[:change]}"]
      message << "from #{details[:from]}" if details[:from].to_s.present?
      message << "to #{details[:to]}" if details[:to].to_s.present?
      message.join(' ')
    end
  end
end
