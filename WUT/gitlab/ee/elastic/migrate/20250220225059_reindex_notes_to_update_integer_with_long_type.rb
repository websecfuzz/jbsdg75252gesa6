# frozen_string_literal: true

class ReindexNotesToUpdateIntegerWithLongType < Elastic::Migration
  include ::Search::Elastic::MigrationReindexTaskHelper

  def targets
    %w[Note]
  end
end
