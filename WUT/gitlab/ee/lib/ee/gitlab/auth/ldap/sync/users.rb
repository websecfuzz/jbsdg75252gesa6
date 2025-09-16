# frozen_string_literal: true

module EE
  module Gitlab
    module Auth
      module Ldap
        module Sync
          class Users
            attr_reader :provider, :proxy

            def self.execute(proxy)
              self.new(proxy).update_permissions
            end

            def initialize(proxy)
              @provider = proxy.provider
              @proxy = proxy
            end

            # rubocop: disable CodeReuse/ActiveRecord
            def update_permissions
              dns = member_dns
              return true if dns.empty?

              current_users_with_attribute = ::User.with_provider(provider).where(attribute => true)
              verified_users_with_attribute = []

              # Verify existing users and add new ones.
              dns.each do |member_dn|
                user = update_user_by_dn(member_dn)
                verified_users_with_attribute << user if user
              end

              # Revoke the unverified users.
              (current_users_with_attribute - verified_users_with_attribute).each do |user|
                user[attribute] = false
                user.save
              end

              true
            rescue ::Gitlab::Auth::Ldap::LdapConnectionError
              ::Gitlab::AppLogger.warn("Error syncing #{attribute} users for provider '#{provider}'. LDAP connection Error")

              false
            end
            # rubocop: enable CodeReuse/ActiveRecord

            private

            def attribute
              raise NotImplementedError
            end

            def member_dns
              raise NotImplementedError
            end

            def update_user_by_dn(member_dn)
              user = ::Gitlab::Auth::Ldap::User.find_by_uid_and_provider(member_dn, provider)

              if user.present?
                user[attribute] = true
                user.save

                user
              else
                ::Gitlab::AppLogger.debug(
                  <<-MSG.strip_heredoc.tr("\n", ' ')
                    #{self.class.name}: User with DN `#{member_dn}` should be marked as
                    #{attribute} but there is no user in GitLab with that identity.
                    Membership will be updated once the user signs in for the first time.
                  MSG
                )

                nil
              end
            end
          end
        end
      end
    end
  end
end
