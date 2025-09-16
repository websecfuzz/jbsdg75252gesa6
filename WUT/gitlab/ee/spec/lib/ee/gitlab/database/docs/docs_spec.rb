# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'validate dictionary' do |all_objects, directory_path, required_fields|
  context 'for each object' do
    let(:directory_path) {  directory_path }

    let(:metadata_allowed_fields) do
      required_fields + %i[
        classes
        description
        introduced_by_url
        milestone
        gitlab_schema
      ]
    end

    let(:metadata) do
      all_objects.each_with_object({}) do |object_name, hash|
        next unless File.exist?(object_metadata_file_path(object_name))

        hash[object_name] ||= load_object_metadata(required_fields, object_name)
      end
    end

    let(:objects_without_metadata) do
      all_objects.reject { |t| metadata.has_key?(t) }
    end

    let(:objects_without_valid_metadata) do
      metadata.select { |_, t| t.has_key?(:error) }.keys
    end

    let(:objects_with_disallowed_fields) do
      metadata.select { |_, t| t.has_key?(:disallowed_fields) }.keys
    end

    let(:objects_with_missing_required_fields) do
      metadata.select { |_, t| t.has_key?(:missing_required_fields) }.keys
    end

    it 'has a metadata file' do
      expect(objects_without_metadata).to be_empty, multiline_error(
        'Missing metadata files',
        objects_without_metadata.map { |t| "  #{object_metadata_file(t)}" }
      )
    end

    it 'has a valid metadata file' do
      expect(objects_without_valid_metadata).to be_empty, object_metadata_errors(
        'Table metadata files with errors',
        :error,
        objects_without_valid_metadata
      )
    end

    it 'has a valid metadata file with allowed fields' do
      expect(objects_with_disallowed_fields).to be_empty, object_metadata_errors(
        'Table metadata files with disallowed fields',
        :disallowed_fields,
        objects_with_disallowed_fields
      )
    end

    it 'has a valid metadata file without missing fields' do
      expect(objects_with_missing_required_fields).to be_empty, object_metadata_errors(
        'Table metadata files with missing fields',
        :missing_required_fields,
        objects_with_missing_required_fields
      )
    end
  end

  private

  def object_metadata_file(object_name)
    File.join(directory_path, "#{object_name}.yml")
  end

  def object_metadata_file_path(object_name)
    Rails.root.join(object_metadata_file(object_name))
  end

  def load_object_metadata(required_fields, object_name)
    result = {}
    begin
      result[:metadata] = YAML.safe_load(File.read(object_metadata_file_path(object_name))).deep_symbolize_keys

      disallowed_fields = (result[:metadata].keys - metadata_allowed_fields)
      result[:disallowed_fields] = "fields not allowed: #{disallowed_fields.join(', ')}" unless disallowed_fields.empty?

      missing_required_fields = (required_fields - result[:metadata].reject { |_, v| v.blank? }.keys)
      unless missing_required_fields.empty?
        result[:missing_required_fields] = "missing required fields: #{missing_required_fields.join(', ')}"
      end
    rescue Psych::SyntaxError => ex
      result[:error] = ex.message
    end
    result
  end

  # rubocop:disable Naming/HeredocDelimiterNaming
  def object_metadata_errors(title, field, objects)
    lines = objects.map do |object_name|
      <<~EOM
        #{object_metadata_file(object_name)}
          #{metadata[object_name][field]}
      EOM
    end

    multiline_error(title, lines)
  end

  def multiline_error(title, lines)
    <<~EOM
      #{title}:

      #{lines.join("\n")}
    EOM
  end
  # rubocop:enable Naming/HeredocDelimiterNaming
end

RSpec.describe 'embedding database documentation', feature_category: :database do
  context 'for views' do
    database_base_models = Gitlab::Database.database_base_models.select { |k, _| k == 'embedding' }
    views = database_base_models.flat_map { |_, m| m.connection.views }.sort.uniq
    directory_path = File.join('ee', 'db', 'embedding', 'docs', 'views')
    required_fields = %i[feature_categories view_name gitlab_schema]

    include_examples 'validate dictionary', views, directory_path, required_fields
  end

  context 'for tables' do
    database_base_models = Gitlab::Database.database_base_models.select { |k, _| k == 'embedding' }
    tables = database_base_models.flat_map { |_, m| m.connection.tables }.sort.uniq
    directory_path = File.join('ee', 'db', 'embedding', 'docs')
    required_fields = %i[feature_categories table_name gitlab_schema]

    include_examples 'validate dictionary', tables, directory_path, required_fields
  end
end

RSpec.describe 'geo database documentation', feature_category: :database do
  context 'for views' do
    database_base_models = Gitlab::Database.database_base_models.select { |k, _| k == 'geo' }
    views = database_base_models.flat_map { |_, m| m.connection.views }.sort.uniq
    directory_path = File.join('ee', 'db', 'geo', 'docs', 'views')
    required_fields = %i[feature_categories view_name gitlab_schema]

    include_examples 'validate dictionary', views, directory_path, required_fields
  end

  context 'for tables' do
    database_base_models = Gitlab::Database.database_base_models.select { |k, _| k == 'geo' }
    tables = database_base_models.flat_map { |_, m| m.connection.tables }.sort.uniq
    directory_path = File.join('ee', 'db', 'geo', 'docs')
    required_fields = %i[feature_categories table_name gitlab_schema]

    include_examples 'validate dictionary', tables, directory_path, required_fields
  end
end
