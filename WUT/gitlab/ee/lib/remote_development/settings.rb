# frozen_string_literal: true

module RemoteDevelopment
  module Settings
    extend Gitlab::Fp::Settings::PublicApi

    # @return [Class]
    def self.settings_main_class
      RemoteDevelopment::Settings::Main
    end
  end
end
