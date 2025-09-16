# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      class ModelMetadata
        def initialize(feature_setting: nil)
          @feature_setting = feature_setting
        end

        def to_params
          model_info = feature_setting&.model_metadata_params

          return model_info if model_info

          amazon_q_params if ::Ai::AmazonQ.connected?
        end

        private

        attr_reader :feature_setting

        def amazon_q_params
          {
            provider: :amazon_q,
            name: :amazon_q,
            role_arn: ::Ai::Setting.instance.amazon_q_role_arn
          }
        end
      end
    end
  end
end
