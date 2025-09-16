# frozen_string_literal: true

FactoryBot.define do
  factory :analyzer_project_status, class: 'Security::AnalyzerProjectStatus' do
    project
    build factory: [:ci_build, :success]
    status { :success }
    analyzer_type { :sast }
    last_call { Time.current }
    archived { false }

    after(:build) do |status, _|
      status.traversal_ids = status.project&.namespace&.traversal_ids
    end

    Enums::Security.extended_analyzer_types.each_key do |type|
      trait type do
        analyzer_type { type }
      end
    end
  end
end
