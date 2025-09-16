# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module Ldap
        # Create a hash map of member DNs to access levels. The highest
        # access level is retained in cases where `set` is called multiple times
        # for the same DN.
        class AccessLevels < Hash
          def set(dns, to:)
            dns.each do |dn|
              current = self[dn]

              # Keep the higher of the access values.
              self[dn] = to if current.nil? || to[:base_access_level] > current[:base_access_level]
            end
          end
        end
      end
    end
  end
end
