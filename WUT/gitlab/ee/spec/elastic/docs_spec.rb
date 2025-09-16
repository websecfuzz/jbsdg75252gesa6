# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Elastic migration documentation', feature_category: :global_search do
  let(:migration_files) { Dir.glob('ee/elastic/migrate/*.rb') }
  let(:dictionary_files) { Dir.glob('ee/elastic/docs/*.yml') }

  it 'has a dictionary record for every migration file' do
    migrations = migration_files.map { |f| f.gsub('ee/elastic/migrate/', '').gsub('.rb', '') }
    dictionaries = dictionary_files.map { |f| f.gsub('ee/elastic/docs/', '').gsub('.yml', '') }

    missing_dictionary_records = migrations - dictionaries

    message = "Expected dictionary files to be present in ee/elastic/docs/ for migrations #{missing_dictionary_records}"
    expect(missing_dictionary_records).to be_empty, message
  end

  it 'defines skip keys for skipped migrations' do
    failed = []
    dictionaries = {}
    skip_keys = %w[skippable skip_condition]

    dictionary_files.each do |file|
      version = file.split('/').last.split('_').first
      dictionaries[version] = file
    end

    Elastic::DataMigrationService.migrations.select(&:skippable?).each do |migration|
      dictionary = dictionaries[migration.version.to_s]
      dictionary_keys = YAML.load_file(dictionary).keys

      failed << migration.name unless skip_keys.all? { |key| dictionary_keys.include?(key) }
    end

    message = "Expected dictionary file for #{failed.join(', ')} to define #{skip_keys.join(', ')}"
    expect(failed).to be_empty, message
  end
end
