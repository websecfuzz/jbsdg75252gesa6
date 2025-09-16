# frozen_string_literal: true

class DataSeeder
  # Factories that will be excluded in the process of creating test data
  EXCLUDED_FACTORIES = %w[
    work_item_type
    widget_definition
    hierarchy_restriction
    related_link_restriction
    cycle_analytics_value_stream_setting
  ].freeze

  def initialize(quiet = false)
    @quiet = quiet # Allows to reduce verbosity when necessary
  end

  # @example bundle exec rake "ee:gitlab:seed:data_seeder[bulk_data.rb]"
  # @example GITLAB_LOG_LEVEL=debug bundle exec rake "ee:gitlab:seed:data_seeder[bulk_data.rb]"
  def seed
    # We seed this before all specs are run. Some seeds are necessary for some factories to work properly
    TestEnv.seed_db
    # Prepare Gitaly projects bundle files to use in factories
    TestEnv.setup_factory_repo
    TestEnv.setup_forked_repo

    seed_all_fixtures
  end

  private

  def allowed_factories
    registry = FactoryBot.factories

    disallowed_factories = EXCLUDED_FACTORIES.map { |factory_name| registry.find(factory_name) }

    registry.without(disallowed_factories)
  end

  def seed_all_fixtures
    allowed_factories.each_with_index do |factory, i|
      retries ||= 0
      # Create a new instance for each factory
      FactoryBot.create(factory.name)
    rescue ActiveRecord::RecordNotUnique => e
      # Workaround for UniqueViolation, context https://gitlab.com/gitlab-org/quality/quality-engineering/team-tasks/-/issues/2354#note_1793812916
      puts "#{factory.name} failed with #{e}! Attempt##{retries}"
      sleep 1
      retry if (retries += 1) < 3
    rescue Exception => e # rubocop:disable Lint/RescueException -- catching all possible exceptions
      # We rescue exception here to make sure seeding proceeds unrelated to various unique exceptions from Factories
      puts "#{factory.name} caught exception #{e} of class #{e.class}!"
    else
      puts "Successfully created Factory #{factory.name}" unless @quiet
    ensure
      puts "Factory ##{i + 1}" unless @quiet
    end
  end
end
