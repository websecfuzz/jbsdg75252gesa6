# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ProvisioningService, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:enabled_namespace) do
    create(:zoekt_enabled_namespace, namespace: namespace, last_rollout_failed_at: 1.day.ago.iso8601)
  end

  let_it_be(:namespace2) { create(:group) }
  let_it_be(:enabled_namespace2) { create(:zoekt_enabled_namespace, namespace: namespace2) }
  let_it_be(:nodes) { create_list(:zoekt_node, 5, total_bytes: 100.gigabytes, used_bytes: 90.gigabytes) }

  let(:plan) do
    {
      namespaces: [
        {
          namespace_id: namespace.id,
          enabled_namespace_id: enabled_namespace.id,
          replicas: [
            {
              indices: [
                {
                  node_id: nodes.first.id,
                  required_storage_bytes: 3.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                },
                {
                  node_id: nodes.second.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                }
              ]
            },
            {
              indices: [
                {
                  node_id: nodes.third.id,
                  required_storage_bytes: 3.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                },
                {
                  node_id: nodes.fourth.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                }
              ]
            }
          ],
          errors: [],
          namespace_required_storage_bytes: 10.gigabytes
        },
        {
          namespace_id: namespace2.id,
          enabled_namespace_id: enabled_namespace2.id,
          replicas: [
            {
              indices: [
                {
                  node_id: nodes.first.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                },
                {
                  node_id: nodes.second.id,
                  required_storage_bytes: 1.gigabyte,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                }
              ]
            },
            {
              indices: [
                {
                  node_id: nodes.third.id,
                  required_storage_bytes: 2.gigabytes,
                  max_storage_bytes: 90.gigabytes,
                  projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                },
                {
                  node_id: nodes.fourth.id,
                  required_storage_bytes: 1.gigabyte,
                  max_storage_bytes: 80.gigabytes,
                  projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                }
              ]
            }
          ],
          errors: [],
          namespace_required_storage_bytes: 6.gigabytes
        }
      ],
      total_required_storage_bytes: 16.gigabytes,
      failures: []
    }
  end

  subject(:provisioning_result) { described_class.execute(plan) }

  describe '.provision' do
    context 'when the plan is valid' do
      it 'provisions all replicas and indices' do
        result = provisioning_result
        # Ensure there are no errors
        expect(result[:errors]).to be_empty
        expect(enabled_namespace.reload.replicas.count).to eq(2)
        expect(enabled_namespace.indices.count).to eq(4)
        expect(enabled_namespace2.reload.replicas.count).to eq(2)
        expect(enabled_namespace2.indices.count).to eq(4)

        idx_metadata = enabled_namespace.replicas.first.indices.find_by_zoekt_node_id(nodes.first).metadata
        expect(idx_metadata).to eq({ 'project_namespace_id_to' => 5, 'project_namespace_id_from' => 1 })
        idx_metadata2 = enabled_namespace.replicas.first.indices.find_by_zoekt_node_id(nodes.second).metadata
        expect(idx_metadata2).to eq({ 'project_namespace_id_from' => 6 })
        idx_metadata3 = enabled_namespace.replicas.second.indices.find_by_zoekt_node_id(nodes.third).metadata
        expect(idx_metadata3).to eq({ 'project_namespace_id_to' => 5, 'project_namespace_id_from' => 1 })
        idx_metadata4 = enabled_namespace.replicas.second.indices.find_by_zoekt_node_id(nodes.fourth).metadata
        expect(idx_metadata4).to eq({ 'project_namespace_id_from' => 6 })
        idx_metadata5 = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.first).metadata
        expect(idx_metadata5).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        idx_metadata6 = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.second).metadata
        expect(idx_metadata6).to eq({ 'project_namespace_id_from' => 4 })
        idx_metadata7 = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.third).metadata
        expect(idx_metadata7).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        index = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.fourth)
        idx_metadata8 = index.metadata
        expect(idx_metadata8).to eq({ 'project_namespace_id_from' => 4 })
        expect(index.reserved_storage_bytes).to eq(1.gigabyte)
        expect(result[:success].size).to eq(4)
        expect(enabled_namespace.last_rollout_failed_at).to be_nil
      end
    end

    context 'when there is not enough space in node' do
      before do
        nodes.second.update!(used_bytes: 99.gigabytes) # Simulate node being near full
      end

      it 'accumulates the error and does not provision indices on that node', :freeze_time do
        result = provisioning_result
        expect(result[:errors]).to include(
          a_hash_including(
            message: 'node_capacity_exceeded',
            failed_namespace_id: namespace.id,
            node_id: nodes.second.id
          )
        )
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
      end
    end

    context 'when there is an error initializing a replica' do
      it 'accumulates the error and does not creates anything', :freeze_time do
        allow(::Search::Zoekt::Replica).to receive(:new).and_raise(StandardError, 'Replica initialization failed')

        result = provisioning_result

        expect(result[:errors]).to include(a_hash_including(message: 'Replica initialization failed'))
        expect(Search::Zoekt::Replica.count).to be_zero
        expect(Search::Zoekt::Index.count).to be_zero
        expect(result[:success]).to be_empty
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
      end
    end

    context 'when one index can not be created among multiple indices from the plan' do
      let(:plan) do
        {
          namespaces: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: non_existing_record_id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 10.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 6.gigabytes
            }
          ],
          total_required_storage_bytes: 16.gigabytes,
          failures: []
        }
      end

      it 'is atomic, per namespace', :freeze_time do
        result = provisioning_result
        expect(result[:errors]).to include(a_hash_including(message: /Couldn't find Search::Zoekt::Node with/))
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
        expect(enabled_namespace.replicas).to be_empty
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
        expect(enabled_namespace2.replicas).not_to be_empty
        expect(enabled_namespace.indices).to be_empty
        expect(enabled_namespace2.indices).not_to be_empty
        expect(result[:success].size).to eq(2)
      end
    end

    context 'when one index reserved_storage_bytes is not sufficient at the time of indices creation', :freeze_time do
      let(:plan) do
        {
          namespaces: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 11.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 16.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 6.gigabytes
            }
          ],
          total_required_storage_bytes: 16.gigabytes,
          failures: []
        }
      end

      it 'skips the namespace, adds metadata for which index can not be created and continue with other namespaces' do
        result = provisioning_result
        expect(result[:errors]).to include(
          a_hash_including(
            message: 'node_capacity_exceeded',
            failed_namespace_id: namespace.id,
            node_id: nodes.first.id
          )
        )
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
        expect(enabled_namespace.metadata['rollout_required_storage_bytes']).to eq(16.gigabytes)
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
        expect(enabled_namespace.replicas).to be_empty
        expect(enabled_namespace2.replicas).not_to be_empty
        expect(enabled_namespace.indices).to be_empty
        expect(enabled_namespace2.indices).not_to be_empty
        expect(result[:success].size).to eq(2)
      end
    end

    context 'when a namespace has errors in its plan' do
      let(:plan) do
        {
          namespaces: [
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 1.gigabyte,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 4, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 6.gigabytes
            }
          ],
          total_required_storage_bytes: 16.gigabytes,
          failures: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.second.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                },
                {
                  indices: [
                    {
                      node_id: nodes.third.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    },
                    {
                      node_id: nodes.fourth.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 80.gigabytes,
                      projects: { project_namespace_id_from: 6, project_namespace_id_to: nil }
                    }
                  ]
                }
              ],
              errors: [{ namespace_id: namespace.id, replica_idx: nil, type: :error_type, details: 'Detail' }],
              namespace_required_storage_bytes: 10.gigabytes
            }
          ]
        }
      end

      it 'skips that namespace, set metadata on enabled_namespace and continues with the rest', :freeze_time do
        result = provisioning_result
        # Ensure there are no errors
        expect(result[:errors]).to be_empty
        expect(enabled_namespace.replicas).to be_empty
        expect(enabled_namespace.indices).to be_empty
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
        expect(enabled_namespace.metadata['rollout_required_storage_bytes']).to eq(10.gigabytes)
        expect(enabled_namespace2.replicas.count).to eq(2)
        expect(enabled_namespace2.indices.count).to eq(4)
        metadata = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.first).metadata
        expect(metadata).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        metadata2 = enabled_namespace2.replicas.first.indices.find_by_zoekt_node_id(nodes.second).metadata
        expect(metadata2).to eq({ 'project_namespace_id_from' => 4 })
        metadata3 = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.third).metadata
        expect(metadata3).to eq({ 'project_namespace_id_to' => 3, 'project_namespace_id_from' => 1 })
        metadata4 = enabled_namespace2.replicas.second.indices.find_by_zoekt_node_id(nodes.fourth).metadata
        expect(metadata4).to eq({ 'project_namespace_id_from' => 4 })
        expect(result[:success].size).to eq(2)
      end
    end

    context 'when namespace is not found' do
      let(:plan) do
        {
          namespaces: [
            {
              namespace_id: non_existing_record_id,
              enabled_namespace_id: enabled_namespace.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 3.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 2.gigabytes
            }
          ],
          total_required_storage_bytes: 5.gigabytes,
          failures: []
        }
      end

      it 'skips that non existing enabled_namespace and continues with the rest', :freeze_time do
        result = provisioning_result
        expect(result[:errors]).to include(
          a_hash_including(
            message: :missing_enabled_namespace, failed_namespace_id: non_existing_record_id
          )
        )
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
      end
    end

    context 'when index is already present for a namespace' do
      let_it_be(:index) { create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace) }
      let(:plan) do
        {
          namespaces: [
            {
              namespace_id: namespace.id,
              enabled_namespace_id: enabled_namespace.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 3.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 5 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 3.gigabytes
            },
            {
              namespace_id: namespace2.id,
              enabled_namespace_id: enabled_namespace2.id,
              replicas: [
                {
                  indices: [
                    {
                      node_id: nodes.first.id,
                      required_storage_bytes: 2.gigabytes,
                      max_storage_bytes: 90.gigabytes,
                      projects: { project_namespace_id_from: 1, project_namespace_id_to: 3 }
                    }
                  ]
                }
              ],
              errors: [],
              namespace_required_storage_bytes: 2.gigabytes
            }
          ],
          total_required_storage_bytes: 5.gigabytes,
          failures: []
        }
      end

      it 'skips the namespace which already has index and continues with the rest', :freeze_time do
        result = provisioning_result
        expect(result[:errors]).to include(a_hash_including(message: :index_already_exists))
        expect(enabled_namespace.reload.last_rollout_failed_at).to eq(Time.current.iso8601)
        expect(result[:success]).to include(a_hash_including(namespace_id: namespace2.id))
      end
    end
  end
end
