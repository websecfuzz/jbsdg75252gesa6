# frozen_string_literal: true

module API
  module Entities
    module Packages
      module Conan
        class PackageManifest < Grape::Entity
          expose :package_urls, merge: true, documentation: { type: 'object', example: '{ "conan_package.tgz": "https://gitlab.example.com/api/v4/packages/conan/v1/files/my-package/1.0/my-group+my-project/stable/packages/103f6067a947f366ef91fc1b7da351c588d1827f/0/conan_package.tgz"' }
        end
      end
    end
  end
end
