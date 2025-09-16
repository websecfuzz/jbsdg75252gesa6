# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::BuildDependencyGraph, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:ancestor) { create(:sbom_occurrence, project: project) }
  let_it_be(:descendant) do
    create(:sbom_occurrence, ancestors: [{ name: ancestor.component_name, version: ancestor.version }, {}],
      input_file_path: ancestor.input_file_path, project: project)
  end

  let_it_be(:grandchild) do
    create(:sbom_occurrence,
      ancestors: [
        { name: descendant.component_name, version: descendant.version },
        { name: descendant.component_name, version: descendant.version }
      ],
      input_file_path: descendant.input_file_path, project: project)
  end

  let_it_be(:grandgrandchild) do
    create(:sbom_occurrence, ancestors: [{ name: grandchild.component_name, version: grandchild.version }],
      input_file_path: grandchild.input_file_path, project: project)
  end

  let_it_be(:deep_one) do
    create(:sbom_occurrence, ancestors: [{ name: grandgrandchild.component_name, version: grandgrandchild.version },
      {}], input_file_path: grandgrandchild.input_file_path, project: project)
  end

  subject(:service) { described_class.new(project) }

  it "builds a dependency tree", :aggregate_failures do
    expect { service.execute }.to change { Sbom::GraphPath.by_projects(project).count }.from(0).to(6)
  end

  it "sets the created_at timestamp of all new records to the same timestamp", :freeze_time do
    service.execute
    now = service.timestamp
    expect(Sbom::GraphPath.by_projects(project).pluck(:created_at)).to match_array([now, now, now, now, now, now])
  end

  it "invokes the remove job after building the tree" do
    expect(Sbom::RemoveOldDependencyGraphsWorker).to receive(:perform_async).with(project.id)
    service.execute
  end

  it "does not store duplicate graph paths" do
    expect { service.execute }.to change {
      Sbom::GraphPath.by_projects(project).where(ancestor: descendant, descendant: grandchild).count
    }.from(0).to(1)
  end

  it "logs the expected message when the build completes" do
    expect(::Gitlab::AppLogger).to receive(:info).with(
      message: "New graph creation complete",
      project: project.name,
      project_id: project.id,
      namespace: project.group.name,
      namespace_id: project.group.id,
      count_path_nodes: 6
    )
    service.execute
  end
end
