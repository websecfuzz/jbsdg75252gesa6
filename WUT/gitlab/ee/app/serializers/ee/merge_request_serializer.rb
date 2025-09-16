# frozen_string_literal: true

module EE
  module MergeRequestSerializer
    extend ::Gitlab::Utils::Override

    override :identified_entity
    def identified_entity(opts)
      if opts[:serializer] == 'ai'
        MergeRequestAiEntity
      else
        super(opts)
      end
    end
  end
end
