# frozen_string_literal: true

module RemoteDevelopment
  module DevfileOperations
    class RestrictionsEnforcer
      include RemoteDevelopmentConstants
      include Messages

      MAX_DEVFILE_SIZE_BYTES = 3.megabytes

      # Since this is called after flattening the devfile, we can safely assume that it has valid syntax
      # as per devfile standard. If you are validating something that is not available across all devfile versions,
      # add additional guard clauses.
      # Devfile standard only allows name/id to be of the format /'^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'/
      # Hence, we do no need to restrict the prefix `gl_`.
      # However, we do that for the 'variables' in the devfile since they do not have any such restriction
      RESTRICTED_PREFIX = "gl-"

      # Currently, we only support 'container' and 'volume' type components.
      # For container components, ensure no endpoint name starts with restricted_prefix
      UNSUPPORTED_COMPONENT_TYPES = %i[kubernetes openshift image].freeze

      # Currently, we only support 'exec' and 'apply' for validation
      SUPPORTED_COMMAND_TYPES = %i[exec apply].freeze

      # Currently, we only support `preStart` events
      SUPPORTED_EVENTS = %i[preStart postStart].freeze

      # Currently, we only support the following options for exec commands
      SUPPORTED_EXEC_COMMAND_OPTIONS = %i[commandLine component label hotReloadCapable].freeze

      # Currently, we only support the default value `false` for the `hotReloadCapable` option
      SUPPORTED_HOT_RELOAD_VALUE = false

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.enforce(context)
        Gitlab::Fp::Result.ok(context)
                          .and_then(method(:validate_devfile_size))
                          .and_then(method(:validate_schema_version))
                          .and_then(method(:validate_parent))
                          .and_then(method(:validate_projects))
                          .and_then(method(:validate_root_attributes))
                          .and_then(method(:validate_components))
                          .and_then(method(:validate_containers))
                          .and_then(method(:validate_endpoints))
                          .and_then(method(:validate_commands))
                          .and_then(method(:validate_events))
                          .and_then(method(:validate_variables))
      end

      private

      # @param [Hash] context
      # @return [Hash] the `processed_devfile` out of the `context` if it exists, otherwise the `devfile`
      def self.devfile_to_validate(context)
        # NOTE: `processed_devfile` is not available in the context until the devfile has been flattened.
        #       If the devfile is flattened, use `processed_devfile`. Else, use `devfile`.
        context[:processed_devfile] || context[:devfile]
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_devfile_size(context)
        devfile = devfile_to_validate(context)

        # Calculate the size of the devfile by converting it to JSON
        devfile_json = devfile.to_json
        devfile_size_bytes = devfile_json.bytesize

        if devfile_size_bytes > MAX_DEVFILE_SIZE_BYTES
          return err(
            format(
              _("Devfile size (%{current_size}) exceeds the maximum allowed size of %{max_size}"),
              current_size: ActiveSupport::NumberHelper.number_to_human_size(devfile_size_bytes),
              max_size: ActiveSupport::NumberHelper.number_to_human_size(MAX_DEVFILE_SIZE_BYTES)
            ),
            context
          )
        end

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_schema_version(context)
        devfile = devfile_to_validate(context)

        devfile_schema_version_string = devfile.fetch(:schemaVersion)
        begin
          devfile_schema_version = Gem::Version.new(devfile_schema_version_string)
        rescue ArgumentError
          return err(
            format(_("Invalid 'schemaVersion' '%{schema_version}'"), schema_version: devfile_schema_version_string),
            context
          )
        end

        minimum_schema_version = Gem::Version.new(REQUIRED_DEVFILE_SCHEMA_VERSION)
        unless devfile_schema_version == minimum_schema_version
          return err(
            format(
              _("'schemaVersion' '%{given_version}' is not supported, it must be '%{required_version}'"),
              given_version: devfile_schema_version_string,
              required_version: REQUIRED_DEVFILE_SCHEMA_VERSION
            ),
            context
          )
        end

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_parent(context)
        devfile = devfile_to_validate(context)

        return err(format(_("Inheriting from 'parent' is not yet supported")), context) if devfile[:parent]

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_projects(context)
        devfile = devfile_to_validate(context)

        return err(_("'starterProjects' is not yet supported"), context) if devfile[:starterProjects]
        return err(_("'projects' is not yet supported"), context) if devfile[:projects]

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_root_attributes(context)
        devfile = devfile_to_validate(context)

        return err(_("Attribute 'pod-overrides' is not yet supported"), context) if devfile.dig(:attributes,
          :"pod-overrides")

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_components(context)
        devfile = devfile_to_validate(context)

        components = devfile[:components]

        return err(_("No components present in devfile"), context) if components.blank?

        injected_main_components = components.select do |component|
          component.dig(:attributes, MAIN_COMPONENT_INDICATOR_ATTRIBUTE.to_sym)
        end

        if injected_main_components.empty?
          return err(
            format(_("No component has '%{attribute}' attribute"), attribute: MAIN_COMPONENT_INDICATOR_ATTRIBUTE),
            context
          )
        end

        if injected_main_components.length > 1
          # noinspection RailsParamDefResolve -- this pluck isn't from ActiveRecord, it's from ActiveSupport
          return err(
            format(
              _("Multiple components '%{name}' have '%{attribute}' attribute"),
              name: injected_main_components.pluck(:name), # rubocop:disable CodeReuse/ActiveRecord -- this pluck isn't from ActiveRecord, it's from ActiveSupport
              attribute: MAIN_COMPONENT_INDICATOR_ATTRIBUTE
            ),
            context
          )
        end

        components_all_have_names = components.all? { |component| component[:name].present? }
        return err(_("Components must have a 'name'"), context) unless components_all_have_names

        components.each do |component|
          component_name = component.fetch(:name)
          # Ensure no component name starts with restricted_prefix
          if component_name.downcase.start_with?(RESTRICTED_PREFIX)
            return err(
              format(
                _("Component name '%{component}' must not start with '%{prefix}'"),
                component: component_name,
                prefix: RESTRICTED_PREFIX
              ),
              context
            )
          end

          UNSUPPORTED_COMPONENT_TYPES.each do |unsupported_component_type|
            if component[unsupported_component_type]
              return err(
                format(_("Component type '%{type}' is not yet supported"), type: unsupported_component_type),
                context
              )
            end
          end

          return err(_("Attribute 'container-overrides' is not yet supported"), context) if component.dig(
            :attributes, :"container-overrides")

          return err(_("Attribute 'pod-overrides' is not yet supported"), context) if component.dig(:attributes,
            :"pod-overrides")
        end

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_containers(context)
        devfile = devfile_to_validate(context)

        components = devfile.fetch(:components)

        components.each do |component|
          container = component[:container]
          next unless container

          if container[:dedicatedPod]
            return err(
              format(
                _("Property 'dedicatedPod' of component '%{name}' is not yet supported"),
                name: component.fetch(:name)
              ),
              context
            )
          end
        end

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_endpoints(context)
        devfile = devfile_to_validate(context)

        components = devfile.fetch(:components)

        err_result = nil

        components.each do |component|
          next unless component.dig(:container, :endpoints)

          container = component.fetch(:container)

          container.fetch(:endpoints).each do |endpoint|
            endpoint_name = endpoint.fetch(:name)
            next unless endpoint_name.downcase.start_with?(RESTRICTED_PREFIX)

            err_result = err(
              format(
                _("Endpoint name '%{endpoint}' of component '%{component}' must not start with '%{prefix}'"),
                endpoint: endpoint_name,
                component: component.fetch(:name),
                prefix: RESTRICTED_PREFIX
              ),
              context
            )
          end
        end

        return err_result if err_result

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_commands(context)
        devfile = devfile_to_validate(context)

        devfile.fetch(:commands, []).each do |command|
          command_id = command.fetch(:id)

          # Check command_id for restricted prefix
          error_result = validate_restricted_prefix(command_id, 'command_id', context)
          return error_result if error_result

          supported_command_type = SUPPORTED_COMMAND_TYPES.find { |type| command[type].present? }

          unless supported_command_type
            return err(
              format(
                _("Command '%{command}' must have one of the supported command types: %{supported_types}"),
                command: command_id,
                supported_types: SUPPORTED_COMMAND_TYPES.join(", ")
              ),
              context
            )
          end

          # Ensure no command is referring to a component with restricted_prefix
          command_type = command[supported_command_type]

          # Check if component is present (required for both exec and apply)
          unless command_type[:component].present?
            return err(
              format(
                _("'%{type}' command '%{command}' must specify a 'component'"),
                type: supported_command_type,
                command: command_id
              ),
              context
            )
          end

          # Check component name for restricted prefix
          component_name = command_type.fetch(:component)

          error_result = validate_restricted_prefix(component_name, 'component_name', context,
            { command: command_id })
          return error_result if error_result

          # Check label for restricted prefix
          command_label = command_type.fetch(:label, "")

          error_result = validate_restricted_prefix(command_label, 'label', context,
            { command: command_id })
          return error_result if command_label.present? && error_result

          # Type-specicific validations for `exec` commands
          # Since we only support the exec command type for user defined poststart events
          # We don't need to have validation for other command types
          next unless supported_command_type == :exec

          exec_command = command_type

          # Validate that only the supported options are used
          unsupported_options = exec_command.keys - SUPPORTED_EXEC_COMMAND_OPTIONS
          if unsupported_options.any?
            return err(
              format(
                _("Unsupported options '%{options}' for exec command '%{command}'. " \
                  "Only '%{supported_options}' are supported."),
                options: unsupported_options.join(", "),
                command: command_id,
                supported_options: SUPPORTED_EXEC_COMMAND_OPTIONS.join(", ")
              ),
              context
            )
          end

          if exec_command.key?(:hotReloadCapable) && exec_command[:hotReloadCapable] != SUPPORTED_HOT_RELOAD_VALUE
            return err(
              format(
                _("Property 'hotReloadCapable' for exec command '%{command}' must be false when specified"),
                command: command_id
              ),
              context
            )
          end
        end

        Gitlab::Fp::Result.ok(context)
      end

      # @param [String] value
      # @param [String] type
      # @param [Hash] context
      # @param [Hash] additional_params
      # @return [Gitlab::Fp::Result.err]
      def self.validate_restricted_prefix(value, type, context, additional_params = {})
        return unless value.downcase.start_with?(RESTRICTED_PREFIX)

        error_messages = {
          'command_id' => _("Command id '%{command}' must not start with '%{prefix}'"),
          'component_name' => _(
            "Component name '%{component}' for command id '%{command}' must not start with '%{prefix}'"
          ),
          'label' => _("Label '%{command_label}' for command id '%{command}' must not start with '%{prefix}'")
        }

        message_template = error_messages[type]
        return unless message_template

        params = { prefix: RESTRICTED_PREFIX }.merge(additional_params)

        case type
        when 'command_id'
          params[:command] = value
        when 'component_name'
          params[:component] = value
        when 'label'
          params[:command_label] = value
        end

        err(format(message_template, params), context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_events(context)
        devfile = devfile_to_validate(context)
        commands = devfile.fetch(:commands, [])

        devfile.fetch(:events, {}).each do |event_type, event_type_events|
          # Ensure no event type other than "preStart" are allowed

          if SUPPORTED_EVENTS.exclude?(event_type) && event_type_events.present?
            err_msg = format(_("Event type '%{type}' is not yet supported"), type: event_type)
            # The entries for unsupported events may be defined, but they must be blank.
            return err(err_msg, context)
          end

          # Ensure no event starts with restricted_prefix
          event_type_events.each do |command_name|
            if command_name.downcase.start_with?(RESTRICTED_PREFIX)
              return err(
                format(
                  _("Event '%{event}' of type '%{event_type}' must not start with '%{prefix}'"),
                  event: command_name,
                  event_type: event_type,
                  prefix: RESTRICTED_PREFIX
                ),
                context
              )
            end

            next unless event_type == :postStart

            # ===== postStart specific validations =====

            # Check if the referenced command is an exec command
            referenced_command = commands.find { |cmd| cmd[:id] == command_name }
            unless referenced_command[:exec].present?
              return err(
                format(
                  _("PostStart event references command '%{command}' which is not an exec command. Only exec " \
                    "commands are supported in postStart events"),
                  command: command_name
                ),
                context
              )
            end
          end
        end

        Gitlab::Fp::Result.ok(context)
      end

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.validate_variables(context)
        devfile = devfile_to_validate(context)

        restricted_prefix_underscore = RESTRICTED_PREFIX.tr("-", "_")

        # Ensure no variable name starts with restricted_prefix
        devfile.fetch(:variables, {}).each_key do |variable|
          [RESTRICTED_PREFIX, restricted_prefix_underscore].each do |prefix|
            next unless variable.downcase.start_with?(prefix)

            return err( # rubocop:disable Cop/AvoidReturnFromBlocks -- We want to use a return here - it works fine, and the alternative is unnecessarily complex.
              format(
                _("Variable name '%{variable}' must not start with '%{prefix}'"),
                variable: variable,
                prefix: prefix
              ),
              context
            )
          end
        end

        Gitlab::Fp::Result.ok(context)
      end

      # @param [String] details
      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.err(details, context)
        Gitlab::Fp::Result.err(DevfileRestrictionsFailed.new({ details: details, context: context }))
      end
      private_class_method :devfile_to_validate, :validate_devfile_size, :validate_schema_version, :validate_parent,
        :validate_projects, :validate_components, :validate_containers,
        :validate_endpoints, :validate_commands, :validate_restricted_prefix, :validate_events,
        :validate_variables, :err, :validate_root_attributes
    end
  end
end
