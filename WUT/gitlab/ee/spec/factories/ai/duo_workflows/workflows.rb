# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workflow, class: 'Ai::DuoWorkflows::Workflow' do
    project { association(:project) }
    user { association(:user, developer_of: project) }
    goal { "Fix pipeline" }
    agent_privileges { [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
    pre_approved_agent_privileges { [] }
    workflow_definition { "software_development" }
    image { "registry.gitlab.com/gitlab-org/duo-workflow/test-image:latest" }
    environment { :ide }

    trait :agentic_chat do
      workflow_definition { "chat" }
    end

    after(:build) do |workflow, _|
      workflow.project_id = nil if workflow.namespace_id
    end
  end
end
