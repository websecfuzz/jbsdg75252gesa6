# frozen_string_literal: true

require "gitlab/safe_request_store"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around(:example, :enable_request_store) do |example|
    ::Gitlab::SafeRequestStore.ensure_request_store { example.run }
  end
end
