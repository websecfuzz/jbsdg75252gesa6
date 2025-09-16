# frozen_string_literal: true

module AppSec
  module Dast
    module SiteProfiles
      module Audit
        class UpdateService < BaseService
          def execute
            new_params.each do |property, new_value|
              old_value = old_params[property]

              case new_value
              when Array
                if new_value.first.instance_of?(Hash) || old_value.first.instance_of?(Hash)
                  next if new_value.flat_map { |k, v| [k, v].join("") }.flatten.sort ==
                    old_value.flat_map { |k, v| [k, v].join("") }.flatten.sort
                elsif old_value.sort == new_value.sort
                  next
                end
              when old_value
                next
              end

              ::Gitlab::Audit::Auditor.audit(
                name: 'dast_site_profile_update',
                author: current_user,
                scope: project,
                target: dast_site_profile,
                message: audit_message(property, new_value, old_value)
              )
            end
          end

          private

          def dast_site_profile
            params[:dast_site_profile]
          end

          def new_params
            params[:new_params]
          end

          def old_params
            params[:old_params]
          end

          def audit_message(property, new_value, old_value)
            case property
            when :auth_password, :request_headers
              "Changed DAST site profile #{property} (secret value omitted)"
            when :excluded_urls, :optional_variables
              "Changed DAST site profile #{property} (long value omitted)"
            else
              "Changed DAST site profile #{property} from #{old_value} to #{new_value}"
            end
          end
        end
      end
    end
  end
end
