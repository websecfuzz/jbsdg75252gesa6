# frozen_string_literal: true

FactoryBot.define do
  factory :pm_license, class: 'PackageMetadata::License' do
    sequence(:spdx_identifier) { |n| "OLDAP-2.#{n}" }

    initialize_with { PackageMetadata::License.find_or_initialize_by(spdx_identifier: spdx_identifier) }

    trait :with_software_license do
      after(:create) do |license|
        name =
          case license.spdx_identifier
          when /OLDAP-*/
            "Open LDAP Public License v#{license.spdx_identifier.split('-')[-1]}"
          when 'BSD'
            'BSD-4-Clause'
          when 'Apache-2.0'
            'Apache License 2.0'
          when 'DEFAULT-2.1'
            'Default License 2.1'
          when 'BSD-4-Clause'
            'BSD 4-Clause "Original" or "Old" License'
          when 'MIT'
            'MIT License'
          when 'BSD-2-Clause'
            'BSD 2-Clause "Simplified" License'
          else
            license.spdx_identifier
          end

        SoftwareLicense.where(spdx_identifier: license.spdx_identifier, name: name).first_or_create!
      end
    end
  end
end
